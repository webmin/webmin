#!/usr/local/bin/perl
# A caller for loading XHR related routines
use strict;

our ($root_directory);

BEGIN { push(@INC, "."); };
use WebminCore;

&init_config();
&ReadParse();
&webmin_user_is_admin() or &switch_to_remote_user();

do "./xhr-lib.pl";
xhr();
