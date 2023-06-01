#!/usr/local/bin/perl
# A caller for loading XHR related routines
use strict;

our ($trust_unknown_referers, $root_directory);

$trust_unknown_referers = 1;

BEGIN { push(@INC, "."); };
use WebminCore;

&init_config();
&ReadParse();
&switch_to_remote_user();
do "$root_directory/XHR-lib.pl";

xhr();
