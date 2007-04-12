#!/usr/local/bin/perl
# Show one RBAC profile

require './rbac-lib.pl';
&ReadParse();
$access{'profs'} == 1 || &error($text{'profs_ecannot'});
if ($in{'new'}) {
	&ui_print_header(undef, $text{'prof_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'prof_title2'}, "");
	$profs = &list_prof_attrs();
	$prof = $profs->[$in{'idx'}];
	}

print &ui_form_start("save_prof.cgi", "post");
print &ui_hidden("idx", $in{'idx'}),"\n";
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_table_start($text{'prof_header'}, "width=100%", 2);

print &ui_table_row($text{'prof_name'},
		    &ui_textbox("name", $prof->{'name'}, 20));

print &ui_table_row($text{'prof_desc'},
		    &ui_textbox("desc", $prof->{'desc'}, 40));

print &ui_table_row($text{'prof_auths'},
		    &auths_input("auths", $prof->{'attr'}->{'auths'}));

print &ui_table_row($text{'prof_profiles'},
		    &profiles_input("profiles", $prof->{'attr'}->{'profs'}, 1));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}

&ui_print_footer("list_profs.cgi", $text{'profs_return'});

