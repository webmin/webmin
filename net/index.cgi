#!/usr/local/bin/perl
# index.cgi
# Display a menu of various network screens

require './net-lib.pl';

# Show friendly name for network config file format
($mode, $ver) = split(/\//, $net_mode);
$mdesc = $text{'index_mode_'.$mode};
if (!$mdesc && $mode =~ /^(.*)-linux$/) {
	$mdesc = ucfirst($1)." Linux";
	}
$mdesc ||= $mode;
$desc = &text('index_mode', $mdesc);

&ui_print_header($desc, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("ifconfig hosts resolve.conf nsswitch.conf", "man"));
$zone = &running_in_zone() || &running_in_vserver();
foreach $i ('ifcs', 'routes', 'dns', 'hosts',
	    ($config{'ipnodes_file'} ? ('ipnodes') : ( ))) {
	next if (!$access{$i});
	next if ($i eq "ifcs" && $zone);

	if ($i eq "ifcs") {
		push(@links, "list_${i}.cgi");
		}
	else {
		push(@links, "list_${i}.cgi");
		}
	push(@titles, $text{"${i}_title"});
	push(@icons, "images/${i}.gif");
	}
&icons_table(\@links, \@titles, \@icons, @icons > 4 ? scalar(@icons) : 4);

if (defined(&apply_network) && $access{'apply'} && !$zone) {
	# Allow the user to apply the network config
	print &ui_hr();
	print &ui_buttons_start();
	print &ui_buttons_row("apply.cgi", $text{'index_apply'},
			      $text{'index_applydesc'});
	print &ui_buttons_end();
	}
&ui_print_footer("/", $text{'index'});

