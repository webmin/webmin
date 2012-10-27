#!/usr/local/bin/perl
# convert_slave.cgi
# Convert a slave/stub zone into a master

require './bind8-lib.pl';
&ReadParse();
&error_setup($text{'convert_err'});

$access{'master'} || &error($text{'mcreate_ecannot'});
$file = &find("file", $zconf->{'members'});
if (!$file) {
	&error($text{'convert_efile'});
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
&redirect("");

