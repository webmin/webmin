#!/usr/local/bin/perl
# Show one RBAC authorization

require './rbac-lib.pl';
$access{'auths'} || &error($text{'auths_ecannot'});
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'auth_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'auth_title2'}, "");
	$auths = &list_auth_attrs();
	$auth = $auths->[$in{'idx'}];
	}

print &ui_form_start("save_auth.cgi", "post");
print &ui_hidden("idx", $in{'idx'}),"\n";
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_table_start($text{'auth_header'}, "width=100%", 2);

print &ui_table_row($text{'auth_name'},
		    &ui_textbox("name", $auth->{'name'}, 20));

print &ui_table_row($text{'auth_short'},
		    &ui_textbox("short", $auth->{'short'}, 40));

print &ui_table_row($text{'auth_desc'},
		    &ui_textbox("desc", $auth->{'desc'}, 60));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}

&ui_print_footer("list_auths.cgi", $text{'auths_return'});

