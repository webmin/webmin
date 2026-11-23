#!/usr/local/bin/perl
# create_swap.cgi
# Attempt to create a swap file, and then redirect the browser back to
# the mounting program to mount it

require './mount-lib.pl';
&ReadParse();
&error_setup($text{'swap_err'});
$access{'create'} && !$access{'only'} && &can_edit_fs("swap", undef, "swap", undef, 1) ||
	&error($text{'edit_ecannot2'});
$in{'cswap_file'} =~ m{\A/} && !-e $in{'cswap_file'} && !-l $in{'cswap_file'} ||
	&error($text{'swap_efile'});
$in{cswap_size} =~ /^\d+$/ ||
	&error(&text('swap_esize', $in{'cswap_size'}));
if ($error = &create_swap($in{cswap_file}, $in{cswap_size}, $in{cswap_units})) {
	&error($error);
	}
&webmin_log("swap", $in{cswap_file});
&redirect("save_mount.cgi?$in");

