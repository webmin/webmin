#!/usr/local/bin/perl
# Create, update or delete a target

use strict;
use warnings;
require './iscsi-target-lib.pl';
our (%text, %in);
&ReadParse();
my $conf = &get_iscsi_config();


