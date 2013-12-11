#!/usr/local/bin/perl
# Show a form for creating or editing a systemd action

require './init-lib.pl';
$access{'bootup'} || &error($text{'edit_ecannot'});
&ReadParse();

if ($in{'new'}) {
	&ui_print_header(undef, $text{'systemd_title1'}, "");
	$u = { };
	}
else {
	&ui_print_header(undef, $text{'systemd_title2'}, "");
	@systemds = &list_systemd_services();
	($u) = grep { $_->{'name'} eq $in{'name'} } @systemds;
	$u || &error($text{'systemd_egone'});
	$u->{'legacy'} && &error($text{'systemd_elegacy'});
	}

print &ui_form_start("save_systemd.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("name", $in{'name'}) if (!$in{'new'});
print &ui_table_start($text{'systemd_header'}, undef, 2);

if ($in{'new'}) {
	# Service name
	print &ui_table_row($text{'systemd_name'},
			    &ui_textbox("name", undef, 30)."<tt>.service</tt>", undef, ["valign=middle","valign=middle"]);

	# Description
	print &ui_table_row($text{'systemd_desc'},
			    &ui_textbox("desc", undef, 60), undef, ["valign=middle","valign=middle"]);

	# Start script
	print &ui_table_row($text{'systemd_start'},
			    &ui_textarea("atstart", undef, 5, 80), undef, ["valign=middle","valign=middle"]);

	# Stop script
	print &ui_table_row($text{'systemd_stop'},
			    &ui_textarea("atstop", undef, 5, 80), undef, ["valign=middle","valign=middle"]);

	# Start at boot?
	print &ui_table_row($text{'systemd_boot'},
			    &ui_yesno_radio("boot", 1), undef, ["valign=middle","valign=middle"]);
	}
else {
	# Service name (non-editable)
	print &ui_table_row($text{'systemd_name'},
			    "<tt>$in{'name'}</tt>", undef, ["valign=middle","valign=middle"]);

	# Config file
	$conf = &read_file_contents($u->{'file'});
	print &ui_table_row($text{'systemd_conf'},
			    &ui_textarea("conf", $conf, 20, 80), undef, ["valign=top","valign=top"]);

	# Current status
	if ($u->{'boot'} != 2) {
		print &ui_table_row($text{'systemd_boot'},
			    &ui_yesno_radio("boot", $u->{'boot'}), undef, ["valign=middle","valign=middle"]);
		}
	print &ui_table_row($text{'systemd_status'},
		$u->{'status'} && $u->{'pid'} ?
			&text('systemd_status1', $u->{'pid'}) :
		$u->{'status'} ?
			$text{'systemd_status2'} :
			$text{'systemd_status0'}, undef, ["valign=middle","valign=middle"]);
	}

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'start', $text{'edit_startnow'} ],
			     [ 'restart', $text{'edit_restartnow'} ],
			     [ 'stop', $text{'edit_stopnow'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

