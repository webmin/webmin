#!/usr/local/bin/perl
# Re-download the root zone servers
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in);

require './bind8-lib.pl';
&error_setup($text{'refetch_err'});
&ReadParse();

# Work out the filename
my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
&can_edit_zone($zone) ||
	&error($text{'hint_ecannot'});
my $file = $zone->{'file'};
my $rootfile = &make_chroot(&absolute_path($file));

# Try to download the root servers file from
# ftp://rs.internic.net/domain/named.root
&lock_file($rootfile);
my $err = &download_root_zone(&absolute_path($file));
&error($err) if ($err);
&unlock_file($rootfile);

&webmin_log("refetch");
&redirect("");

