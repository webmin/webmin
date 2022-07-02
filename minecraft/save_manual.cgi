#!/usr/local/bin/perl
# Manually save the config file

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%in, %text);
&ReadParseMime();
&error_setup($text{'manual_err'});

$in{'conf'} =~ /\S/ || &error($text{'manual_econf'});
$in{'conf'} =~ s/\r//g;

my $fh = "CONF";
&open_lock_tempfile($fh, ">".&get_minecraft_config_file());
&print_tempfile($fh, $in{'conf'});
&close_tempfile($fh);
&webmin_log("manual");
&redirect("");
