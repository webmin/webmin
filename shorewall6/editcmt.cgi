#!/usr/bin/perl
# Display a form for editing or creating a comment

require './shorewall6-lib.pl';
&ReadParse();
&get_clean_table_name(\%in);
&can_access($in{'table'}) || &error($text{'list_ecannot'});
if ($in{'new'}) {
	&ui_print_header(undef, $text{"comment_create"}, "");
	}
else {
	&ui_print_header(undef, $text{"comment_edit"}, "");
	$pfunc = &get_parser_func(\%in);
	@table = &read_table_file($in{'table'}, $pfunc);
	$row = $table[$in{'idx'}];
	}

print &ui_form_start("savecmt.cgi", "post");
foreach $f ("table", "new", "idx") {
	print &ui_hidden($f, $in{$f});
	}
print &ui_table_start($text{'comment_header'}, 2);

print &ui_table_row($text{'comment_msg'},
		    &ui_textbox("msg", join(" ", @$row[1..@$row-1]), 60));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}

&ui_print_footer("list.cgi?table=$in{'table'}", $text{$in{'tableclean'}."_return"});

