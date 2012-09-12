#!/usr/local/bin/perl
# Display icons for iSCSI option types

use strict;
use warnings;
require './iscsi-client-lib.pl';
our (%text, %config, $module_name);

&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);

my $err = &check_config();
if ($err) {
	&ui_print_endpage(
		$err." ".&text('index_clink', "../config.cgi?$module_name"));
	}

my @links = ( "edit_auth.cgi", "edit_timeout.cgi",
	      "edit_iscsi.cgi", "list_conns.cgi" );
my @titles = ( $text{'auth_title'}, $text{'timeout_title'},
	       $text{'iscsi_title'}, $text{'conns_title'} );
my @icons = ( "images/auth.gif", "images/timeout.gif",
	      "images/iscsi.gif", "images/conns.gif" );
&icons_table(\@links, \@titles, \@icons, 4);

&ui_print_footer("/", $text{'index'});
