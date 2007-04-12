#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <auth_attr.h>
#include <secdb.h>

MODULE = Authen::SolarisRBAC		PACKAGE = Authen::SolarisRBAC		

int
chkauth(authname, username)
	char *authname
	char *username
	CODE:
		RETVAL = chkauthattr(authname, username);
	OUTPUT:
		RETVAL


