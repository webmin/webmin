#!/usr/local/bin/perl
# Re-download the root zone servers

require './bind8-lib.pl';
&error_setup($text{'refetch_err'});
&ReadParse();

# Work out the filename
$zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
&can_edit_zone($zone, $view) ||
	&error($text{'hint_ecannot'});
$file = $zone->{'file'};
$rootfile = &make_chroot(&absolute_path($file));

# Try to download the root servers file from
# ftp://rs.internic.net/domain/named.root
&lock_file($rootfile);
$err = &download_root_zone(&absolute_path($file));
&error($err) if ($err);
&unlock_file($rootfile);

&webmin_log("refetch");
&redirect("");

