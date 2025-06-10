#!/usr/local/bin/perl
# Return a list of other Webmin servers as JSON

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './servers-lib.pl';

# Get servers and apply search
my @servers = &list_servers_sorted(1);
print_json(\@servers);
