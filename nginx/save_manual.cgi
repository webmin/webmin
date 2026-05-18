#!/usr/local/bin/perl
# Update one config file

use strict;
use warnings;
require './nginx-lib.pl';
&ReadParseMime();
our (%text, %in, %access);
&error_setup($text{'manual_err'});
&can_edit_manual_config() || &error($text{'manual_ecannot'});

my @files = &get_manual_config_files();
&indexof($in{'file'}, @files) >= 0 || &error($text{'manual_efile'});

# Follow links to get the real file
while(-l $in{'file'}) {
	$in{'file'} = readlink($in{'file'});
	}
$in{'file'} || &error($text{'manual_elink'});

$in{'data'} =~ s/\r//g;
my $fh = "CONF";
if ($in{'test'}) {
	# Backup the file, write to it, and then test the config
	my $temp = &transname();
	&copy_source_dest($in{'file'}, $temp);
	&open_lock_tempfile($fh, ">$in{'file'}");
	&print_tempfile($fh, $in{'data'});
	&close_tempfile($fh);
	my $err = &test_config();
	if ($err) {
		# Bad config .. roll back
		&copy_source_dest($temp, $in{'file'});
		&unlink_file($temp);
		&error(&text('restart_etest',
			     "<tt>".&html_escape($err)."</tt>"));
		}
	&unlink_file($temp);
	}
else {
	# Just write out
	&open_lock_tempfile($fh, ">$in{'file'}");
	&print_tempfile($fh, $in{'data'});
	&close_tempfile($fh);
	}
&update_last_config_change();
&webmin_log("manual", undef, $in{'file'});
&redirect("");
