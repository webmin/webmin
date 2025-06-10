#!/usr/local/bin/perl
# Show a form for editing or creating a BSD rc script

require './init-lib.pl';
&ReadParse();
$access{'bootup'} || &error($text{'edit_ecannot'});

if ($in{'new'}) {
	&ui_print_header(undef, $text{'create_title'}, "");
	$rc = { 'enabled' => 1 };
	}
else {
	&ui_print_header(undef, $text{'edit_title'}, "");
	@rcs = &list_rc_scripts();
	($rc) = grep { $_->{'name'} eq $in{'name'} } @rcs;
	$rc || &error($text{'edit_egone'});
	}

print &ui_form_start("save_rc.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_table_start($text{'edit_details'}, "width=100%", 2);

if ($in{'new'}) {
	# When creating, show start/stop/status input fields
	print &ui_table_row($text{'edit_name'},
		&ui_textbox("name", undef, 20));

	print &ui_table_row($text{'edit_startcmd'},
		&ui_textbox("start_cmd", undef, 70));

	print &ui_table_row($text{'edit_stopcmd'},
		&ui_textbox("stop_cmd", undef, 70));

	print &ui_table_row($text{'edit_statuscmd'},
		&ui_textbox("status_cmd", undef, 70));
	}
else {
	# Just show fill action file contents
	print &ui_table_row($text{'edit_name'}, "<tt>$in{'name'}</tt>");
	print &ui_hidden("name", $in{'name'});

	$script = &read_file_contents($rc->{'file'});
	print &ui_table_row($text{'edit_script'},
		&ui_textarea("script", $script, 20, 70));
	}

# Enabled at boot option
if ($rc->{'enabled'} != 2) {
	print &ui_table_row($text{'edit_boot'},
		&ui_yesno_radio("enabled", int($rc->{'enabled'})));
	}

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     undef,
			     [ "start", $text{'edit_startnow'} ],
			     $rc->{'startstop'} ? 
			        ( [ "stop", $text{'edit_stopnow'} ] ) : ( ),
			     undef,
			     $rc->{'standard'} ?
				( ) : ( [ "delete", $text{'delete'} ] ) ]);
	}

&ui_print_footer("", $text{'index_return'});

