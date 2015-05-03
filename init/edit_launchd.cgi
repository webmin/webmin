#!/usr/local/bin/perl
# Show a form for creating or editing a launchd agent

require './init-lib.pl';
$access{'bootup'} || &error($text{'edit_ecannot'});
&ReadParse();

if ($in{'new'}) {
	&ui_print_header(undef, $text{'launchd_title1'}, "");
	$u = { };
	}
else {
	&ui_print_header(undef, $text{'launchd_title2'}, "");
	@systemds = &list_launchd_agents();
	($u) = grep { $_->{'name'} eq $in{'name'} } @systemds;
	$u || &error($text{'launchd_egone'});
	}

print &ui_form_start("save_launchd.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("name", $in{'name'}) if (!$in{'new'});
print &ui_table_start($text{'launchd_header'}, undef, 2);

if ($in{'new'}) {
	# Service name
	print &ui_table_row($text{'launchd_name'},
			    &ui_textbox("name", undef, 30));

	# Server command and args
	print &ui_table_row($text{'launchd_start'},
			    &ui_textarea("atstart", undef, 5, 80));

	# Start at boot?
	print &ui_table_row($text{'upstart_boot'},
			    &ui_yesno_radio("boot", 1));
	}
else {
	# Service name (non-editable)
	print &ui_table_row($text{'launchd_name'},
			    "<tt>$in{'name'}</tt>");

	# Config file location
	print &ui_table_row($text{'launchd_file'},
			    $u->{'file'} ? "<tt>$u->{'file'}</tt>"
					 : "<i>$text{'launchd_nofile'}</i>");

	if ($u->{'file'}) {
		# Config file contents
		$conf = &read_file_contents($u->{'file'});
		print &ui_table_row($text{'launchd_conf'},
				    &ui_textarea("conf", $conf, 20, 80));
		}

	# Current status
	print &ui_table_row($text{'launchd_status'},
		$u->{'status'} && $u->{'pid'} ?
			&text('systemd_status1', $u->{'pid'}) :
		$u->{'status'} ?
			$text{'systemd_status2'} :
			$text{'systemd_status0'});
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
			     [ 'reload', $text{'edit_reloadnow2'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

