#!/usr/local/bin/perl
# A caller for loading XHR related routines
use strict;

our ($root_directory, %access);

BEGIN { push(@INC, "."); };
use WebminCore;

&init_config();
&ReadParse();
%access = &get_module_acl();
&webmin_user_is_admin() or &switch_to_remote_user();

do "./xhr-lib.pl";
xhr();
