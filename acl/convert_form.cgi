#!/usr/local/bin/perl
# convert_form.cgi
# Display a form for converting unix users to webmin users

require './acl-lib.pl';
$access{'sync'} && $access{'create'} || &error($text{'convert_ecannot'});
&ui_print_header(undef, $text{'convert_title'}, "");

@glist = &list_groups();
if ($access{'gassign'} ne '*') {
	@gcan = split(/\s+/, $access{'gassign'});
	@glist = grep { &indexof($_->{'name'}, @gcan) >= 0 } @glist;
	}
if (!@glist) {
	print "$text{'convert_nogroups'}<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

print "$text{'convert_desc'}<p>\n";
print &ui_form_start("convert.cgi", "post");
print &ui_radio_table("conv", 0,
	[ [ 0, $text{'convert_0'} ],
	  [ 1, $text{'convert_1'}, &ui_textbox("users", undef, 60)." ".
				   &user_chooser_button("users", 1) ],
	  [ 2, $text{'convert_2'}, &ui_textbox("nusers", undef, 60)." ".
				   &user_chooser_button("nusers", 1) ],
	  [ 3, $text{'convert_3'}, &unix_group_input("group") ],
	  [ 4, $text{'convert_4'}, &ui_textbox("min", undef, 6)." - ".
				   &ui_textbox("max", undef, 6) ]
	]);

print $text{'convert_group'}," ",
      &ui_select("wgroup", undef, [ map { $_->{'name'} } @glist ]),"<br>\n";
print &ui_checkbox("sync", 1, $text{'convert_sync'}, 1),"<p>\n";

print &ui_form_end([ [ undef, $text{'convert_ok'} ] ]);

&ui_print_footer("", $text{'index_return'});

