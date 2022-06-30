#!/usr/local/bin/perl
# Delete a list of allowed addresses

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-target-lib.pl';
our (%text, %in);
&ReadParse();
&error_setup($text{'dallow_err'});

# Get them
&lock_file(&get_allow_file($in{'mode'}));
my $allow = &get_allow_config($in{'mode'});
my @delallow = map { $allow->[$_] } split(/\0/, $in{'d'});
@delallow || &error($text{'dallow_enone'});

# Delete, bottom up
foreach my $a (reverse(@delallow)) {
	&delete_allow($a);
	}

&unlock_file(&get_allow_file($in{'mode'}));
if (@delallow == 1) {
	&webmin_log("delete", $in{'mode'}, $delallow[0]->{'name'});
	}
else {
	&webmin_log("multidelete", $in{'mode'}, scalar(@delallow));
	}
&redirect("list_allow.cgi?mode=$in{'mode'}");

