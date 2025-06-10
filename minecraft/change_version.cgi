#!/usr/local/bin/perl
# Update the current version

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%in, %text, %config);
&ReadParse();

my @vers = &list_installed_versions();
my ($v) = grep { $_->{'file'} eq $in{'ver'} } @vers;
$v || &error($text{'versions_echange'}." ".$in{'ver'});
if ($in{'restart'}) {
	&stop_minecraft_server(1);
	}
&save_minecraft_jar($in{'ver'});
if ($in{'restart'}) {
	&start_minecraft_server();
	}
&webmin_log("changeversion", undef, $in{'ver'});
&redirect("");
