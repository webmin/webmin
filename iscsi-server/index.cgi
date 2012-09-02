#!/usr/local/bin/perl
# Display icons for iSCSI extents, devices and targets

use strict;
use warnings;
require './iscsi-server-lib.pl';
our (%text);

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

my $err = &check_config();
if ($err) {
	&ui_print_endpage(
		$err." ".&text('index_clink', "../config.cgi?$module_name"));
	}

my @links = ( "list_extents.cgi", "list_devices.cgi",
	      "list_targets.cgi" );
my @titles = ( $text{'extents_title'}, $text{'devices_title'},
	       $text{'targets_title'} );
my @icons = ( "images/extents.gif", "images/devices.gif",
	      "images/targets.gif" );
&icons_table(\@links, \@titles, \@icons);

print &ui_hr();
print &ui_buttons_start();

# Show start/stop/restart buttons
my $pid = &is_iscsi_server_running();
if ($pid) {
	}
else {
	}

# Show start at boot button
# XXX

&ui_print_footer("/", $text{'index'});
