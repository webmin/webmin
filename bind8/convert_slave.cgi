#!/usr/local/bin/perl
# convert_slave.cgi
# Convert a slave/stub zone into a master
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
# Globals
our (%access, %text, %in);

require './bind8-lib.pl';
&ReadParse();
&error_setup($text{'convert_err'});

my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
my $zconf = &zone_to_config($zone);

$access{'master'} || &error($text{'mcreate_ecannot'});
my $file = &find_value("file", $zconf->{'members'});
if (!$file) {
	&error($text{'convert_efile'});
	}
$file = &make_chroot(&absolute_path($file));
if (!-s $file) {
	&error(&text('convert_efilesize', $file));
	}
&lock_file(&make_chroot($zconf->{'file'}));

# Change the type directive
&save_directive($zconf, 'type', [ { 'name' => 'type',
				    'values' => [ 'master' ] } ], 1);

# Take out directives not allowed in masters
&save_directive($zconf, 'masters', [ ], 1);
&save_directive($zconf, 'max-transfer-time-in', [ ], 1);

&flush_file_lines();
&unlock_file(&make_chroot($zconf->{'file'}));

# Convert from binary slave format to text
if (&is_raw_format_records($file)) {
	&has_command("named-compilezone") ||
		&error($text{'convert_ebinary'});
	my $temp = &transname();
	&copy_source_dest($file, $temp);
	my $out = &backquote_logged("named-compilezone -f raw -F text ".
				 "-o $file $zone->{'name'} $temp 2>&1");
	&error(&text('convert_ecompile', "<tt>".&html_escape($out)."</tt>"))
		if ($?);
	&unlink_file($temp);
	}

&redirect("");

