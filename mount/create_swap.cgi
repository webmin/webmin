#!/usr/local/bin/perl
# create_swap.cgi
# Attempt to create a swap file, and then redirect the browser back to
# the mounting program to mount it

require './mount-lib.pl';
&ReadParse();
&error_setup($text{'swap_err'});
$in{cswap_size} =~ /^\d+$/ ||
	&error(&text('swap_esize', $in{'cswap_size'}));
if ($error = &create_swap($in{cswap_file}, $in{cswap_size}, $in{cswap_units})) {
	&error($error);
	}
&webmin_log("swap", $in{cswap_file});
&redirect("save_mount.cgi?$in");

