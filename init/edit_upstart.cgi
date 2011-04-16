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

	# Description

	# Pre-start script

	# Server command
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
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

