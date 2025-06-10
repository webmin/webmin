#!/usr/local/bin/perl
# Move an allowed address down

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-target-lib.pl';
our (%text, %in);
&ReadParse();

&lock_file(&get_allow_file($in{'mode'}));
my $allow = &get_allow_config($in{'mode'});
my $a = $allow->[$in{'idx'}];
my $s = $allow->[$in{'idx'}+1];
($a->{'line'}, $s->{'line'}) = ($s->{'line'}, $a->{'line'});
&modify_allow($a);
&modify_allow($s);

&webmin_log('move', $in{'mode'}, $a->{'name'});
&lock_file(&get_allow_file($in{'mode'}));
&redirect("list_allow.cgi?mode=$in{'mode'}");

