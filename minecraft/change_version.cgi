#!/usr/local/bin/perl
# Update the current version

use strict;
use warnings;
require './minecraft-lib.pl';
our (%in, %text, %config);
&ReadParse();

my @vers = &list_installed_versions();
my ($v) = grep { $_->{'file'} eq $in{'ver'} } @vers;
$v || &error($text{'versions_echange'}." ".$in{'ver'});
&save_minecraft_jar($in{'ver'});
&webmin_log("changeversion", undef, $in{'ver'});
&redirect("");
