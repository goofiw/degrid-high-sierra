dnl This is m4 source.
dnl Process using m4 to produce 'C' language file.
dnl
dnl If you see this line, you can ignore the next one.
/* Do not edit this file. It is produced from the corresponding .m4 source */
dnl
/*
 *	Copyright 1996, University Corporation for Atmospheric Research
 *      See netcdf/COPYRIGHT file for copying and redistribution conditions.
 */
/* $Id: attr.m4,v 2.22 2002/06/20 14:40:57 steve Exp $ */

#include "nc.h"
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "ncx.h"
#include "fbits.h"
#include "rnd.h"


/*
 * Free attr
 * Formerly
NC_free_attr()
 */
void
free_NC_attr(NC_attr *attrp)
{

	if(attrp == NULL)
		return;
	free_NC_string(attrp->name);
	free(attrp);
}


/*
 * How much space will 'nelems' of 'type' take in
 *  external representation (as the values of an attribute)?
 */
static size_t
ncx_len_NC_attrV(nc_type type, size_t nelems)
{
	switch(type) {
	case NC_BYTE:
	case NC_CHAR:
		return ncx_len_char(nelems);
	case NC_SHORT:
		return ncx_len_short(nelems);
	case NC_INT:
		return ncx_len_int(nelems);
	case NC_FLOAT:
		return ncx_len_float(nelems);
	case NC_DOUBLE:
		return ncx_len_double(nelems);
	}
	/* default */
	assert("ncx_len_NC_attr bad type" == 0);
	return 0;
}


NC_attr *
new_x_NC_attr(
	NC_string *strp,
	nc_type type,
	size_t nelems)
{
	NC_attr *attrp;
	const size_t xsz = ncx_len_NC_attrV(type, nelems);
	size_t sz = M_RNDUP(sizeof(NC_attr));

	assert(!(xsz == 0 && nelems != 0));

	sz += xsz;

	attrp = (NC_attr *) malloc(sz);
	if(attrp == NULL )
		return NULL;

	attrp->xsz = xsz;

	attrp->name = strp;
	attrp->type = type;
	attrp->nelems = nelems;
	if(xsz != 0)
		attrp->xvalue = (char *)attrp + M_RNDUP(sizeof(NC_attr));
	else
		attrp->xvalue = NULL;

	return(attrp);
}


/*
 * Formerly
NC_new_attr(name,type,count,value)
 */
static NC_attr *
new_NC_attr(
	const char *name,
	nc_type type,
	size_t nelems)
{
	NC_string *strp;
	NC_attr *attrp;

	assert(name != NULL && *name != 0);

	strp = new_NC_string(strlen(name), name);
	if(strp == NULL)
		return NULL;
	
	attrp = new_x_NC_attr(strp, type, nelems);
	if(attrp == NULL)
	{
		free_NC_string(strp);
		return NULL;
	}

	return(attrp);
}


static NC_attr *
dup_NC_attr(const NC_attr *rattrp)
{
	NC_attr *attrp = new_NC_attr(rattrp->name->cp,
		 rattrp->type, rattrp->nelems);
	if(attrp == NULL)
		return NULL;
	(void) memcpy(attrp->xvalue, rattrp->xvalue, rattrp->xsz);
	return attrp;
}

/* attrarray */

/*
 * Free the stuff "in" (referred to by) an NC_attrarray.
 * Leaves the array itself allocated.
 */
void
free_NC_attrarrayV0(NC_attrarray *ncap)
{
	assert(ncap != NULL);

	if(ncap->nelems == 0)
		return;

	assert(ncap->value != NULL);

	{
		NC_attr **app = ncap->value;
		NC_attr *const *const end = &app[ncap->nelems];
		for( /*NADA*/; app < end; app++)
		{
			free_NC_attr(*app);
			*app = NULL;
		}
	}
	ncap->nelems = 0;
}


/*
 * Free NC_attrarray values.
 * formerly
NC_free_array()
 */
void
free_NC_attrarrayV(NC_attrarray *ncap)
{
	assert(ncap != NULL);
	
	if(ncap->nalloc == 0)
		return;

	assert(ncap->value != NULL);

	free_NC_attrarrayV0(ncap);

	free(ncap->value);
	ncap->value = NULL;
	ncap->nalloc = 0;
}


int
dup_NC_attrarrayV(NC_attrarray *ncap, const NC_attrarray *ref)
{
	int status = NC_NOERR;

	assert(ref != NULL);
	assert(ncap != NULL);

	if(ref->nelems != 0)
	{
		const size_t sz = ref->nelems * sizeof(NC_attr *);
		ncap->value = (NC_attr **) malloc(sz);
		if(ncap->value == NULL)
			return NC_ENOMEM;

		(void) memset(ncap->value, 0, sz);
		ncap->nalloc = ref->nelems;
	}

	ncap->nelems = 0;
	{
		NC_attr **app = ncap->value;
		const NC_attr **drpp = (const NC_attr **)ref->value;
		NC_attr *const *const end = &app[ref->nelems];
		for( /*NADA*/; app < end; drpp++, app++, ncap->nelems++)
		{
			*app = dup_NC_attr(*drpp);
			if(*app == NULL)
			{
				status = NC_ENOMEM;
				break;
			}
		}
	}

	if(status != NC_NOERR)
	{
		free_NC_attrarrayV(ncap);
		return status;
	}

	assert(ncap->nelems == ref->nelems);

	return NC_NOERR;
}


/*
 * Add a new handle on the end of an array of handles
 * Formerly
NC_incr_array(array, tail)
 */
static int
incr_NC_attrarray(NC_attrarray *ncap, NC_attr *newelemp)
{
	NC_attr **vp;

	assert(ncap != NULL);

	if(ncap->nalloc == 0)
	{
		assert(ncap->nelems == 0);
		vp = (NC_attr **) malloc(NC_ARRAY_GROWBY * sizeof(NC_attr *));
		if(vp == NULL)
			return NC_ENOMEM;

		ncap->value = vp;
		ncap->nalloc = NC_ARRAY_GROWBY;
	}
	else if(ncap->nelems +1 > ncap->nalloc)
	{
		vp = (NC_attr **) realloc(ncap->value,
			(ncap->nalloc + NC_ARRAY_GROWBY) * sizeof(NC_attr *));
		if(vp == NULL)
			return NC_ENOMEM;
	
		ncap->value = vp;
		ncap->nalloc += NC_ARRAY_GROWBY;
	}

	if(newelemp != NULL)
	{
		ncap->value[ncap->nelems] = newelemp;
		ncap->nelems++;
	}
	return NC_NOERR;
}


NC_attr *
elem_NC_attrarray(const NC_attrarray *ncap, size_t elem)
{
	assert(ncap != NULL);
		/* cast needed for braindead systems with signed size_t */
	if(ncap->nelems == 0 || (unsigned long) elem >= ncap->nelems)
		return NULL;

	assert(ncap->value != NULL);

	return ncap->value[elem];
}

/* End attarray per se */

/*
 * Given ncp and varid, return ptr to array of attributes
 *  else NULL on error
 */
static NC_attrarray *
NC_attrarray0( NC *ncp, int varid)
{
	NC_attrarray *ap;

	if(varid == NC_GLOBAL) /* Global attribute, attach to cdf */
	{
		ap = &ncp->attrs;
	}
	else if(varid >= 0 && (size_t) varid < ncp->vars.nelems)
	{
		NC_var **vpp;
		vpp = (NC_var **)ncp->vars.value;
		vpp += varid;
		ap = &(*vpp)->attrs;
	} else {
		ap = NULL;
	}
	return(ap);
}


/*
 * Step thru NC_ATTRIBUTE array, seeking match on name.
 *  return match or NULL if Not Found.
 */
NC_attr **
NC_findattr(const NC_attrarray *ncap, const char *name)
{
	NC_attr **attrpp;
	size_t attrid;
	size_t slen;

	assert(ncap != NULL);

	if(ncap->nelems == 0)
		return NULL;

	attrpp = (NC_attr **) ncap->value;

	slen = strlen(name);

	for(attrid = 0; attrid < ncap->nelems; attrid++, attrpp++)
	{
		if(strlen((*attrpp)->name->cp) == slen &&
			strncmp((*attrpp)->name->cp, name, slen) == 0)
		{
			return(attrpp); /* Normal return */
		}
	}
	return(NULL);
}


/*
 * Look up by ncid, varid and name, return NULL if not found
 */
static int 
NC_lookupattr(int ncid,
	int varid,
	const char *name, /* attribute name */
	NC_attr **attrpp) /* modified on return */
{
	int status;
	NC *ncp;
	NC_attrarray *ncap;
	NC_attr **tmp;

	status = NC_check_id(ncid, &ncp);
	if(status != NC_NOERR)
		return status;

	ncap = NC_attrarray0(ncp, varid);
	if(ncap == NULL)
		return NC_ENOTVAR;

	tmp = NC_findattr(ncap, name);
	if(tmp == NULL)
		return NC_ENOTATT;

	if(attrpp != NULL)
		*attrpp = *tmp;

	return ENOERR;
}

/* Public */

int
nc_inq_attname(int ncid, int varid, int attnum, char *name)
{
	int status;
	NC *ncp;
	NC_attrarray *ncap;
	NC_attr *attrp;

	status = NC_check_id(ncid, &ncp);
	if(status != NC_NOERR)
		return status;

	ncap = NC_attrarray0(ncp, varid);
	if(ncap == NULL)
		return NC_ENOTVAR;

	attrp = elem_NC_attrarray(ncap, (size_t)attnum);
	if(attrp == NULL)
		return NC_ENOTATT;

	(void) strncpy(name, attrp->name->cp, attrp->name->nchars);
	name[attrp->name->nchars] = 0;

	return NC_NOERR;
}


int 
nc_inq_attid(int ncid, int varid, const char *name, int *attnump)
{
	int status;
	NC *ncp;
	NC_attrarray *ncap;
	NC_attr **attrpp;

	status = NC_check_id(ncid, &ncp);
	if(status != NC_NOERR)
		return status;

	ncap = NC_attrarray0(ncp, varid);
	if(ncap == NULL)
		return NC_ENOTVAR;
	

	attrpp = NC_findattr(ncap, name);
	if(attrpp == NULL)
		return NC_ENOTATT;

	if(attnump != NULL)
		*attnump = (int)(attrpp - ncap->value);

	return NC_NOERR;
}

int 
nc_inq_atttype(int ncid, int varid, const char *name, nc_type *datatypep)
{
	int status;
	NC_attr *attrp;

	status = NC_lookupattr(ncid, varid, name, &attrp);
	if(status != NC_NOERR)
		return status;

	if(datatypep != NULL)
		*datatypep = attrp->type;

	return NC_NOERR;
}

int 
nc_inq_attlen(int ncid, int varid, const char *name, size_t *lenp)
{
	int status;
	NC_attr *attrp;

	status = NC_lookupattr(ncid, varid, name, &attrp);
	if(status != NC_NOERR)
		return status;

	if(lenp != NULL)
		*lenp = attrp->nelems;

	return NC_NOERR;
}

int
nc_inq_att(int ncid,
	int varid,
	const char *name, /* input, attribute name */
	nc_type *datatypep,
	size_t *lenp)
{
	int status;
	NC_attr *attrp;

	status = NC_lookupattr(ncid, varid, name, &attrp);
	if(status != NC_NOERR)
		return status;

	if(datatypep != NULL)
		*datatypep = attrp->type;
	if(lenp != NULL)
		*lenp = attrp->nelems;

	return NC_NOERR;
}


int
nc_rename_att( int ncid, int varid, const char *name, const char *newname)
{
	int status;
	NC *ncp;
	NC_attrarray *ncap;
	NC_attr **tmp;
	NC_attr *attrp;
	NC_string *newStr, *old;

			/* sortof inline clone of NC_lookupattr() */
	status = NC_check_id(ncid, &ncp);
	if(status != NC_NOERR)
		return status;

	if(NC_readonly(ncp))
		return NC_EPERM;

	ncap = NC_attrarray0(ncp, varid);
	if(ncap == NULL)
		return NC_ENOTVAR;

	status = NC_check_name(newname);
	if(status != NC_NOERR)
		return status;

	tmp = NC_findattr(ncap, name);
	if(tmp == NULL)
		return NC_ENOTATT;
	attrp = *tmp;
			/* end inline clone NC_lookupattr() */

	if(NC_findattr(ncap, newname) != NULL)
	{
		/* name in use */
		return NC_ENAMEINUSE;
	}

	old = attrp->name;
	if(NC_indef(ncp))
	{
		newStr = new_NC_string(strlen(newname), newname);
		if( newStr == NULL)
			return NC_ENOMEM;
		attrp->name = newStr;
		free_NC_string(old);
		return NC_NOERR;
	}
	/* else */
	status = set_NC_string(old, newname);
	if( status != NC_NOERR)
		return status;

	set_NC_hdirty(ncp);

	if(NC_doHsync(ncp))
	{
		status = NC_sync(ncp);
		if(status != NC_NOERR)
			return status;
	}

	return NC_NOERR;
}


int
nc_copy_att(int ncid_in, int varid_in, const char *name, int ncid_out, int ovarid)
{
	int status;
	NC_attr *iattrp;
	NC *ncp;
	NC_attrarray *ncap;
	NC_attr **attrpp;
	NC_attr *old = NULL;
	NC_attr *attrp;

	status = NC_lookupattr(ncid_in, varid_in, name, &iattrp);
	if(status != NC_NOERR)
		return status;

	status = NC_check_id(ncid_out, &ncp);
	if(status != NC_NOERR)
		return status;

	if(NC_readonly(ncp))
		return NC_EPERM;

	ncap = NC_attrarray0(ncp, ovarid);
	if(ncap == NULL)
		return NC_ENOTVAR;

	attrpp = NC_findattr(ncap, name);
	if(attrpp != NULL) /* name in use */
	{
		if(!NC_indef(ncp) )
		{
			attrp = *attrpp; /* convenience */
	
			if(iattrp->xsz > attrp->xsz)
				return NC_ENOTINDEFINE;
			/* else, we can reuse existing without redef */
			
			attrp->xsz = iattrp->xsz;
			attrp->type = iattrp->type;
			attrp->nelems = iattrp->nelems;

			(void) memcpy(attrp->xvalue, iattrp->xvalue,
				iattrp->xsz);
			
			set_NC_hdirty(ncp);

			if(NC_doHsync(ncp))
			{
				status = NC_sync(ncp);
				if(status != NC_NOERR)
					return status;
			}

			return NC_NOERR;
		}
		/* else, redefine using existing array slot */
		old = *attrpp;
	} 
	else
	{
		if(!NC_indef(ncp))
			return NC_ENOTINDEFINE;

		if(ncap->nelems >= NC_MAX_ATTRS)
			return NC_EMAXATTS;
	}

	attrp = new_NC_attr(name, iattrp->type, iattrp->nelems);
	if(attrp == NULL)
		return NC_ENOMEM;

	(void) memcpy(attrp->xvalue, iattrp->xvalue,
		iattrp->xsz);

	if(attrpp != NULL)
	{
		assert(old != NULL);
		*attrpp = attrp;
		free_NC_attr(old);
	}
	else
	{
		status = incr_NC_attrarray(ncap, attrp);
		if(status != NC_NOERR)
		{
			free_NC_attr(attrp);
			return status;
		}
	}

	return NC_NOERR;
}


int
nc_del_att(int ncid, int varid, const char *name)
{
	int status;
	NC *ncp;
	NC_attrarray *ncap;
	NC_attr **attrpp;
	NC_attr *old = NULL;
	int attrid;
	size_t slen;

	status = NC_check_id(ncid, &ncp);
	if(status != NC_NOERR)
		return status;

	if(!NC_indef(ncp))
		return NC_ENOTINDEFINE;

	ncap = NC_attrarray0(ncp, varid);
	if(ncap == NULL)
		return NC_ENOTVAR;

			/* sortof inline NC_findattr() */
	slen = strlen(name);

	attrpp = (NC_attr **) ncap->value;
	for(attrid = 0; (size_t) attrid < ncap->nelems; attrid++, attrpp++)
	{
		if( slen == (*attrpp)->name->nchars &&
			strncmp(name, (*attrpp)->name->cp, slen) == 0)
		{
			old = *attrpp;
			break;
		}
	}
	if( (size_t) attrid == ncap->nelems )
		return NC_ENOTATT;
			/* end inline NC_findattr() */

	/* shuffle down */
	for(attrid++; (size_t) attrid < ncap->nelems; attrid++)
	{
		*attrpp = *(attrpp + 1);
		attrpp++;
	}
	*attrpp = NULL;
	/* decrement count */
	ncap->nelems--;

	free_NC_attr(old);

	return NC_NOERR;
}

dnl
dnl XNCX_PAD_PUTN(Type)
dnl
define(`XNCX_PAD_PUTN',dnl
`dnl
static int
ncx_pad_putn_I$1(void **xpp, size_t nelems, const $1 *tp, nc_type type)
{
	switch(type) {
	case NC_CHAR:
		return NC_ECHAR;
	case NC_BYTE:
		return ncx_pad_putn_schar_$1(xpp, nelems, tp);
	case NC_SHORT:
		return ncx_pad_putn_short_$1(xpp, nelems, tp);
	case NC_INT:
		return ncx_putn_int_$1(xpp, nelems, tp);
	case NC_FLOAT:
		return ncx_putn_float_$1(xpp, nelems, tp);
	case NC_DOUBLE:
		return ncx_putn_double_$1(xpp, nelems, tp);
	}
	assert("ncx_pad_putn_I$1 invalid type" == 0);
	return NC_EBADTYPE;
}
')dnl
dnl
dnl XNCX_PAD_GETN(Type)
dnl
define(`XNCX_PAD_GETN',dnl
`dnl
static int
ncx_pad_getn_I$1(const void **xpp, size_t nelems, $1 *tp, nc_type type)
{
	switch(type) {
	case NC_CHAR:
		return NC_ECHAR;
	case NC_BYTE:
		return ncx_pad_getn_schar_$1(xpp, nelems, tp);
	case NC_SHORT:
		return ncx_pad_getn_short_$1(xpp, nelems, tp);
	case NC_INT:
		return ncx_getn_int_$1(xpp, nelems, tp);
	case NC_FLOAT:
		return ncx_getn_float_$1(xpp, nelems, tp);
	case NC_DOUBLE:
		return ncx_getn_double_$1(xpp, nelems, tp);
	}
	assert("ncx_pad_getn_I$1 invalid type" == 0);
	return NC_EBADTYPE;
}
')dnl
dnl Implement

XNCX_PAD_PUTN(uchar)
XNCX_PAD_GETN(uchar)

XNCX_PAD_PUTN(schar)
XNCX_PAD_GETN(schar)

XNCX_PAD_PUTN(short)
XNCX_PAD_GETN(short)

XNCX_PAD_PUTN(int)
XNCX_PAD_GETN(int)

XNCX_PAD_PUTN(long)
XNCX_PAD_GETN(long)

XNCX_PAD_PUTN(float)
XNCX_PAD_GETN(float)

XNCX_PAD_PUTN(double)
XNCX_PAD_GETN(double)


int
nc_put_att_text(int ncid, int varid, const char *name,
	size_t nelems, const char *value)
{
	int status;
	NC *ncp;
	NC_attrarray *ncap;
	NC_attr **attrpp;
	NC_attr *old = NULL;
	NC_attr *attrp;

	status = NC_check_id(ncid, &ncp);
	if(status != NC_NOERR)
		return status;

	if(NC_readonly(ncp))
		return NC_EPERM;

	ncap = NC_attrarray0(ncp, varid);
	if(ncap == NULL)
		return NC_ENOTVAR;

	status = NC_check_name(name);
	if(status != NC_NOERR)
		return status;

		/* cast needed for braindead systems with signed size_t */
	if((unsigned long) nelems > X_INT_MAX) /* backward compat */
		return NC_EINVAL; /* Invalid nelems */

	if(nelems != 0 && value == NULL)
		return NC_EINVAL; /* Null arg */

	attrpp = NC_findattr(ncap, name);
	if(attrpp != NULL) /* name in use */
	{
		if(!NC_indef(ncp) )
		{
			const size_t xsz = ncx_len_NC_attrV(NC_CHAR, nelems);
			attrp = *attrpp; /* convenience */
	
			if(xsz > attrp->xsz)
				return NC_ENOTINDEFINE;
			/* else, we can reuse existing without redef */
			
			attrp->xsz = xsz;
			attrp->type = NC_CHAR;
			attrp->nelems = nelems;

			if(nelems != 0)
			{
				void *xp = attrp->xvalue;
				status = ncx_pad_putn_text(&xp, nelems, value);
				if(status != NC_NOERR)
					return status;
			}
			
			set_NC_hdirty(ncp);

			if(NC_doHsync(ncp))
			{
				status = NC_sync(ncp);
				if(status != NC_NOERR)
					return status;
			}

			return NC_NOERR;
		}
		/* else, redefine using existing array slot */
		old = *attrpp;
	} 
	else
	{
		if(!NC_indef(ncp))
			return NC_ENOTINDEFINE;

		if(ncap->nelems >= NC_MAX_ATTRS)
			return NC_EMAXATTS;
	}

	attrp = new_NC_attr(name, NC_CHAR, nelems);
	if(attrp == NULL)
		return NC_ENOMEM;

	if(nelems != 0)
	{
		void *xp = attrp->xvalue;
		status = ncx_pad_putn_text(&xp, nelems, value);
		if(status != NC_NOERR)
			return status;
	}

	if(attrpp != NULL)
	{
		assert(old != NULL);
		*attrpp = attrp;
		free_NC_attr(old);
	}
	else
	{
		status = incr_NC_attrarray(ncap, attrp);
		if(status != NC_NOERR)
		{
			free_NC_attr(attrp);
			return status;
		}
	}

	return NC_NOERR;
}


int
nc_get_att_text(int ncid, int varid, const char *name, char *str)
{
	int status;
	NC_attr *attrp;

	status = NC_lookupattr(ncid, varid, name, &attrp);
	if(status != NC_NOERR)
		return status;

	if(attrp->nelems == 0)
		return NC_NOERR;

	if(attrp->type != NC_CHAR)
		return NC_ECHAR;

	/* else */
	{
		const void *xp = attrp->xvalue;
		return ncx_pad_getn_text(&xp, attrp->nelems, str);
	}
}


dnl
dnl NC_PUT_ATT(Abbrv, Type)
dnl
define(`NC_PUT_ATT',dnl
`dnl
int
nc_put_att_$1(int ncid, int varid, const char *name,
	nc_type type, size_t nelems, const $2 *value)
{
	int status;
	NC *ncp;
	NC_attrarray *ncap;
	NC_attr **attrpp;
	NC_attr *old = NULL;
	NC_attr *attrp;

	status = NC_check_id(ncid, &ncp);
	if(status != NC_NOERR)
		return status;

	if(NC_readonly(ncp))
		return NC_EPERM;

	ncap = NC_attrarray0(ncp, varid);
	if(ncap == NULL)
		return NC_ENOTVAR;

	status = nc_cktype(type);
	if(status != NC_NOERR)
		return status;

	if(type == NC_CHAR)
		return NC_ECHAR;

		/* cast needed for braindead systems with signed size_t */
	if((unsigned long) nelems > X_INT_MAX) /* backward compat */
		return NC_EINVAL; /* Invalid nelems */

	if(nelems != 0 && value == NULL)
		return NC_EINVAL; /* Null arg */

	attrpp = NC_findattr(ncap, name);
	if(attrpp != NULL) /* name in use */
	{
		if(!NC_indef(ncp) )
		{
			const size_t xsz = ncx_len_NC_attrV(type, nelems);
			attrp = *attrpp; /* convenience */
	
			if(xsz > attrp->xsz)
				return NC_ENOTINDEFINE;
			/* else, we can reuse existing without redef */
			
			attrp->xsz = xsz;
			attrp->type = type;
			attrp->nelems = nelems;

			if(nelems != 0)
			{
				void *xp = attrp->xvalue;
				status = ncx_pad_putn_I$1(&xp, nelems,
					value, type);
			}
			
			set_NC_hdirty(ncp);

			if(NC_doHsync(ncp))
			{
				const int lstatus = NC_sync(ncp);
				/*
				 * N.B.: potentially overrides NC_ERANGE
				 * set by ncx_pad_putn_I$1
				 */
				if(lstatus != ENOERR)
					return lstatus;
			}

			return status;
		}
		/* else, redefine using existing array slot */
		old = *attrpp;
	} 
	else
	{
		if(!NC_indef(ncp))
			return NC_ENOTINDEFINE;

		if(ncap->nelems >= NC_MAX_ATTRS)
			return NC_EMAXATTS;
	}

	status = NC_check_name(name);
	if(status != NC_NOERR)
		return status;

	attrp = new_NC_attr(name, type, nelems);
	if(attrp == NULL)
		return NC_ENOMEM;

	if(nelems != 0)
	{
		void *xp = attrp->xvalue;
		status = ncx_pad_putn_I$1(&xp, nelems,
			value, type);
	}

	if(attrpp != NULL)
	{
		assert(old != NULL);
		*attrpp = attrp;
		free_NC_attr(old);
	}
	else
	{
		const int lstatus = incr_NC_attrarray(ncap, attrp);
		/*
		 * N.B.: potentially overrides NC_ERANGE
		 * set by ncx_pad_putn_I$1
		 */
		if(lstatus != NC_NOERR)
		{
			free_NC_attr(attrp);
			return lstatus;
		}
	}

	return status;
}
')dnl
dnl
dnl NC_GET_ATT(Abbrv, Type)
dnl
define(`NC_GET_ATT',dnl
`dnl
int
nc_get_att_$1(int ncid, int varid, const char *name, $2 *tp)
{
	int status;
	NC_attr *attrp;

	status = NC_lookupattr(ncid, varid, name, &attrp);
	if(status != NC_NOERR)
		return status;

	if(attrp->nelems == 0)
		return NC_NOERR;

	if(attrp->type == NC_CHAR)
		return NC_ECHAR;

	{
	const void *xp = attrp->xvalue;
	return ncx_pad_getn_I$1(&xp, attrp->nelems, tp, attrp->type);
	}
}
')dnl


NC_PUT_ATT(schar, signed char)
NC_GET_ATT(schar, signed char)

NC_PUT_ATT(uchar, unsigned char)
NC_GET_ATT(uchar, unsigned char)

NC_PUT_ATT(short, short)
NC_GET_ATT(short, short)

NC_PUT_ATT(int, int)
NC_GET_ATT(int, int)

NC_PUT_ATT(long, long)
NC_GET_ATT(long, long)

NC_PUT_ATT(float, float)
NC_GET_ATT(float, float)

NC_PUT_ATT(double, double)
NC_GET_ATT(double, double)


/* deprecated, used to support the 2.x interface */
int
nc_put_att(
	int ncid,
	int varid,
	const char *name,
	nc_type type,
	size_t nelems,
	const void *value)
{
	switch (type) {
	case NC_BYTE:
		return nc_put_att_schar(ncid, varid, name, type, nelems,
			(schar *)value);
	case NC_CHAR:
		return nc_put_att_text(ncid, varid, name, nelems,
			(char *)value);
	case NC_SHORT:
		return nc_put_att_short(ncid, varid, name, type, nelems,
			(short *)value);
	case NC_INT:
#if (SIZEOF_INT >= X_SIZEOF_INT)
		return nc_put_att_int(ncid, varid, name, type, nelems,
			(int *)value);
#elif SIZEOF_LONG == X_SIZEOF_INT
		return nc_put_att_long(ncid, varid, name, type, nelems,
			(long *)value);
#endif
	case NC_FLOAT:
		return nc_put_att_float(ncid, varid, name, type, nelems,
			(float *)value);
	case NC_DOUBLE:
		return nc_put_att_double(ncid, varid, name, type, nelems,
			(double *)value);
	}
	return NC_EBADTYPE;
}


/* deprecated, used to support the 2.x interface */
int
nc_get_att(int ncid, int varid, const char *name, void *value)
{
	int status;
	NC_attr *attrp;

	status = NC_lookupattr(ncid, varid, name, &attrp);
	if(status != NC_NOERR)
		return status;

	switch (attrp->type) {
	case NC_BYTE:
		return nc_get_att_schar(ncid, varid, name,
			(schar *)value);
	case NC_CHAR:
		return nc_get_att_text(ncid, varid, name,
			(char *)value);
	case NC_SHORT:
		return nc_get_att_short(ncid, varid, name,
			(short *)value);
	case NC_INT:
#if (SIZEOF_INT >= X_SIZEOF_INT)
		return nc_get_att_int(ncid, varid, name,
			(int *)value);
#elif SIZEOF_LONG == X_SIZEOF_INT
		return nc_get_att_long(ncid, varid, name,
			(long *)value);
#endif
	case NC_FLOAT:
		return nc_get_att_float(ncid, varid, name,
			(float *)value);
	case NC_DOUBLE:
		return nc_get_att_double(ncid, varid, name,
			(double *)value);
	}
	return NC_EBADTYPE;
}
