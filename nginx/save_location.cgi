#!/usr/local/bin/perl
# Create, update or delete a location block

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %in, %config, %access);
&error_setup($text{'location_err'});
&ReadParse();

# Get the current location
&lock_all_config_files();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});
&can_edit_server($server) || &error($text{'server_ecannot'});
my $conf = &get_config();
my @locations = &find("location", $server);
my $location;
my $old_name;
my @words = ( $in{'path'} );
unshift(@words, $in{'match'}) if ($in{'match'});
if ($in{'new'}) {
	$location = { 'name' => 'location',
		      'type' => 1,
		      'words' => \@words,
		      'members' => [ ] };
	}
else {
	$location = &find_location($server, $in{'oldpath'});
        $location || &error($text{'location_egone'});
        }

# Check for clash
if ($in{'new'} || $in{'oldpath'} ne $in{'path'}) {
	foreach my $l (@locations) {
		&location_path($l) eq $in{'path'} &&
			&error($text{'location_eclash'});
		}
	}

my $action;
my $name;
if ($in{'delete'}) {
	if ($in{'confirm'}) {
		# Got confirmation, delete it
		&save_directive($server, [ $location ], [ ]);
		$action = 'delete';
		}
	else {
		# Ask for confirmation first
		&ui_print_header(&location_desc($server, $location),
				 $text{'location_edit'}, "");

		print &ui_confirmation_form("save_location.cgi",
			&text('location_rusure',
			      "<tt>".&html_escape(&location_path($location))."</tt>"),
			[ [ 'id', $in{'id'} ],
			  [ 'oldpath', $in{'oldpath'} ],
			  [ 'delete', 1 ] ],
			[ [ 'confirm', $text{'server_confirm'} ] ],
			);

		&ui_print_footer("edit_location.cgi?id=".&urlize($in{'id'}).
				   "&path=".&urlize($in{'oldpath'}),
				 $text{'server_return'});
		}
	}
else {
	# Validate path
	$in{'path'} =~ /^\S+$/ || &error($text{'location_epath'});

	if ($in{'new'}) {
		# Create a new location object
		&save_directive($server, [ ], [ $location ]);
		$action = 'create';
		}
	else {
		# Update path in existing one
		$location->{'words'} = \@words;
		&save_directive($server, [ $location ], [ $location ]);
		$action = 'modify';
		}

	# Update root directory
	&nginx_text_parse("root", $location, undef, '^\/\S+$');
	&can_directory($in{'root'}) ||
		&error(&text('location_ecannot',
			     "<tt>".&html_escape($in{'root'})."</tt>",
			     "<tt>".&html_escape($access{'root'})."</tt>"));
	}

&flush_config_file_lines();
&unlock_all_config_files();
if ($action) {
	my $name = &find_value("server_name", $server);
	&webmin_log($action, 'location', &location_path($location),
		    { 'server' => $name });
	&redirect("edit_server.cgi?id=".&urlize($in{'id'}));
	}


