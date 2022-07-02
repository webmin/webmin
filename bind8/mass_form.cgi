#!/usr/local/bin/perl
# Form for creating multiple zones from an uploaded file, local file or text
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %config);

require './bind8-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'mass_title'}, "");

print "$text{'mass_desc'}<p>\n";

print &ui_form_start("mass_create.cgi", "form-data");
print &ui_table_start($text{'mass_header'}, "100%", 2);

print &ui_table_row($text{'mass_local'},
		    &ui_textbox("local", undef, 40)."\n".
		    &file_chooser_button("local"));

print &ui_table_row($text{'mass_upload'},
		    &ui_upload("upload", 40));

print &ui_table_row($text{'mass_text'},
		    &ui_textarea("text", undef, 5, 40));

print &ui_table_row($text{'mass_tmpl'},
		    &ui_yesno_radio("tmpl", 1));

my @servers = &list_slave_servers();
if (@servers && $access{'remote'}) {
	print &ui_table_row($text{'mass_onslave'},
	    &ui_radio("onslave", 1,
		[ [ 0, $text{'no'} ], [ 1, $text{'master_onslaveyes'} ] ])." ".
	    &ui_textbox("mip", $config{'this_ip'} ||
		 &to_ipaddress(&get_system_hostname()), 30));
	}

my @views = grep { $_->{'type'} eq 'view' && &can_edit_view($_) }
	      &list_zone_names();
if (@views) {
	print &ui_table_row($text{'mass_view'},
		    &ui_select("view", undef,
			[ map { [ $_->{'index'}, $_->{'name'} ] } @views ]));
	}

print &ui_table_end();
print &ui_form_end([ [ "ok", $text{'mass_ok'} ] ]);

&ui_print_footer("", $text{'index_return'});

