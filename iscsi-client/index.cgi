#!/usr/local/bin/perl
# Display icons for iSCSI option types

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-client-lib.pl';
our (%text, %config, $module_name);

&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
		 &help_search_link("iscsiadm", "man", "doc", "google"));

my $err = &check_config();
if ($err) {
	&ui_print_endpage(
		$err." ".&text('index_clink', "../config.cgi?$module_name"));
	}

my @links = ( "edit_auth.cgi", "edit_timeout.cgi",
	      "edit_iscsi.cgi", "list_ifaces.cgi",
	      "list_conns.cgi" );
my @titles = ( $text{'auth_title'}, $text{'timeout_title'},
	       $text{'iscsi_title'}, $text{'ifaces_title'},
	       $text{'conns_title'} );
my @icons = ( "images/auth.gif", "images/timeout.gif",
	      "images/iscsi.gif", "images/ifaces.gif",
	      "images/conns.gif" );
&icons_table(\@links, \@titles, \@icons, 5);

if ($config{'init_name'}) {
	# Show start at boot button
	print &ui_hr();
	print &ui_buttons_start();

	&foreign_require("init");
	my $all_starting = 1;
	foreach my $i (split(/\s+/, $config{'init_name'})) {
		my $starting = &init::action_status($i);
		$all_starting = 0 if ($starting != 2);
		}
	print &ui_buttons_row(
		"atboot.cgi",
		$text{'index_atboot'},
		$text{'index_atbootdesc'},
		undef,
		&ui_radio("boot", $all_starting,
			  [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

	print &ui_buttons_end();
	}

&ui_print_footer("/", $text{'index'});
