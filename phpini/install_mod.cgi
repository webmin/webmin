#!/usr/local/bin/perl
# Install the package for a given PHP module, based on the version

require './phpini-lib.pl';
&ReadParse();
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});
$access{'global'} || &error($text{'mods_ecannot'});
$in{'mod'} =~ /^\S+$/ || &error($text{'mods_emod'});

