#!/usr/local/bin/perl
# Show the config for one location inside a server block

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %in, %access);
&ReadParse();
my $server = &find_server($in{'id'});
$server || &error($text{'server_egone'});
&can_edit_server($server) || &error($text{'server_ecannot'});

my $location;
if ($in{'new'}) {
	&ui_print_header(&server_desc($server), $text{'location_create'}, "");
	$location = { 'name' => 'location',
		      'words' => [ ],
		      'members' => [ ] };
	}
else {
	$location = &find_location($server, $in{'path'});
	$location || &error($text{'location_egone'});
	&ui_print_header(&location_desc($server, $location),
			 $text{'location_edit'}, "");
	}

if ($in{'path'}) {
	# Show icons for location types
	print &ui_subheading($text{'location_settings'});
	my @lpages = ( "ldocs", "lfcgi", "lssi", "lgzip", "lproxy",
		       "laccess", "lrewrite", );
	&icons_table(
		[ map { "edit_".$_.".cgi?id=".&urlize($in{'id'}).
			"&path=".&urlize($in{'path'}) } @lpages ],
		[ map { $text{$_."_title"} } @lpages ],
		[ map { "images/".$_.".gif" } @lpages ],
		);

	print &ui_hr();
	}

# Show form to edit location path and root
if (!$in{'new'}) {
	print &ui_subheading($text{'location_location'});
	}
print &ui_form_start("save_location.cgi", "post");
print &ui_hidden("id", $in{'id'});
print &ui_hidden("new", $in{'new'});
print &ui_hidden("oldpath", $in{'path'});
print &ui_table_start($text{'location_header'}, "width=100%", 2);

# Location path
my @w = @{$location->{'words'}};
print &ui_table_row($text{'location_path'},
	&ui_textbox("path", @w ? $w[$#w] : "", 60));

# Match type
print &ui_table_row($text{'location_match'},
	&ui_select("match", @w > 1 ? $w[0] : "",
		   [ map { [ $_, &match_desc($_) ] } &list_match_types() ],
		   1, 0, 1));

# Root directory
print &nginx_text_input("root", $location, 60,
			&file_chooser_button("root", 1));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'location_delete'} ] ]);
	}

&ui_print_footer("edit_server.cgi?id=".&urlize($in{'id'}),
		 $text{'server_return'});
