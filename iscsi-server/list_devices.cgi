#!/usr/local/bin/perl
# List all devices (combined devices)

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-server-lib.pl';
our (%text);
my $conf = &get_iscsi_config();

&ui_print_header(undef, $text{'devices_title'}, "");

my @devices = &find($conf, "device");
my @links = ( &ui_link("edit_device.cgi?new=1",$text{'devices_add'}) );
if (@devices) {
	unshift(@links, &select_all_link("d"), &select_invert_link("d"));
	print &ui_form_start("delete_devices.cgi");
	print &ui_links_row(\@links);
	my @tds = ( "width=5" );
	print &ui_columns_start([ undef, 
				  $text{'devices_name'},
				  $text{'devices_mode'},
				  $text{'devices_extents'} ], 100, 0, \@tds);
	my %omap = map { $_->{'type'}.$_->{'num'}, $_ } @$conf;
	foreach my $e (@devices) {
		print &ui_checked_columns_row([
			&ui_link("edit_device.cgi?num=$e->{'num'}","$e->{'type'}.$e->{'num'}"),
			$text{'devices_mode_'.$e->{'mode'}} ||
			  uc($e->{'mode'}),
			join("&nbsp;|&nbsp;",
				map { &describe_object($omap{$_}) } @{$e->{'extents'}}),
			], \@tds, "d", $e->{'num'});
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ undef, $text{'devices_delete'} ] ]);
	}
else {
	print "<b>$text{'devices_none'}</b><p>\n";
	print &ui_links_row(\@links);
	}

&ui_print_footer("", $text{'index_return'});
