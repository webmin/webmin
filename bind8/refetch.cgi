#!/usr/local/bin/perl
# Re-download the root zone servers

require './bind8-lib.pl';
&error_setup($text{'refetch_err'});
&ReadParse();

# Work out the filename
$zone = &get_zone_name($in{'index'}, $in{'view'});
&can_edit_zone($zone, $view) ||
	&error($text{'hint_ecannot'});
$file = $zone->{'file'};
$file = &make_chroot(&absolute_path($file));

# Try to download the root servers file from
# ftp://rs.internic.net/domain/named.root
&lock_file($file);
&ftp_download("rs.internic.net", "/domain/named.root", $file);
&unlock_file($file);

&webmin_log("refetch");
&redirect("");

