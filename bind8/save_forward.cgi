#!/usr/local/bin/perl
# save_forward.cgi
# Save changes to forward zone options in named.conf
use strict;
use warnings;
our (%access, %text, %in);

require './bind8-lib.pl';
&ReadParse();
&error_setup($text{'fwd_err'});

my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
my $z = &zone_to_config($zone);
my $zconf = $z->{'members'};
my $dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'master_ecannot'});
my $indent = $zone->{'view'} ? 2 : 1;

&lock_file(&make_chroot($z->{'file'}));
$access{'ro'} && &error($text{'master_ero'});

&save_forwarders("forwarders", $z, $indent);
&save_choice("check-names", $z, $indent);
&save_choice("forward", $z, $indent);
&flush_file_lines();
&unlock_file(&make_chroot($z->{'file'}));
&webmin_log("opts", undef, $dom, \%in);
&redirect("");

