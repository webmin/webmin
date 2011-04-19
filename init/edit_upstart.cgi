#!/usr/local/bin/perl
# Show a form for creating or editing an upstart action

require './init-lib.pl';
$access{'bootup'} || &error($text{'edit_ecannot'});
&ReadParse();

if ($in{'new'}) {
	&ui_print_header(undef, $text{'upstart_title1'}, "");
	$u = { };
	}
else {
	&ui_print_header(undef, $text{'upstart_title2'}, "");
	@upstarts = &list_upstart_services();
	($u) = grep { $_->{'name'} eq $in{'name'} } @upstarts;
	$u || &error($text{'upstart_egone'});
	$u->{'legacy'} && &error($text{'upstart_elegacy'});
	}

print &ui_form_start("save_upstart.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("name", $in{'name'}) if (!$in{'new'});
print &ui_table_start($text{'upstart_header'}, undef, 2);

if ($in{'new'}) {
	# Service name
	print &ui_table_row($text{'upstart_name'},
			    &ui_textbox("name", undef, 30));

	# Description
	print &ui_table_row($text{'upstart_desc'},
			    &ui_textbox("desc", undef, 60));

	# Pre-start script
	print &ui_table_row($text{'upstart_prestart'},
			    &ui_textarea("prestart", undef, 5, 80));

	# Server command
	print &ui_table_row($text{'upstart_server'},
			    &ui_textbox("server", undef, 60)."<br>\n".
			    &ui_checkbox("fork", 1, $text{'upstart_fork'}, 0));

	# Start at boot?
	print &ui_table_row($text{'upstart_boot'},
			    &ui_yesno_radio("boot", 1));
	}
else {
	# Service name (non-editable)
	print &ui_table_row($text{'upstart_name'},
			    "<tt>$in{'name'}</tt>");

	# Config file
	$cfile = "/etc/init/$in{'name'}.conf";
	$conf = &read_file_contents($cfile);
	print &ui_table_row($text{'upstart_conf'},
			    &ui_textarea("conf", $conf, 20, 80));

	# Current status
	if ($u->{'boot'} eq 'start' || $u->{'boot'} eq 'stop') {
		print &ui_table_row($text{'upstart_boot'},
			    &ui_yesno_radio("boot", $u->{'boot'} eq 'start'));
		}
	if ($u->{'status'} eq 'waiting' || $u->{'status'} eq 'running') {
		print &ui_table_row($text{'upstart_status'},
			$u->{'status'} eq 'waiting' ? $text{'upstart_status0'} :
				&text('upstart_status1', $u->{'pid'}));
		}
	}

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'start', $text{'edit_startnow'} ],
			     [ 'stop', $text{'edit_stopnow'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

