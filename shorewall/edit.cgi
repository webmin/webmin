#!/usr/bin/perl
# edit.cgi
# Display a form for editing or creating a table entry

require './shorewall-lib.pl';
&ReadParse();
&get_clean_table_name(\%in);
&can_access($in{'table'}) || &error($text{'list_ecannot'});
if ($in{'new'}) {
	# Show where the new entry will be inserted, if not at the end
	if ($in{'before'} ne '') {
		$msg = &text('edit_before', $in{'before'}+1);
		}
	elsif ($in{'after'} ne '') {
		$msg = &text('edit_after', $in{'after'}+1);
		}
	&ui_print_header($msg, $text{$in{'tableclean'}."_create"}, "");
	}
else {
	&ui_print_header(undef, $text{$in{'tableclean'}."_edit"}, "");
	$pfunc = &get_parser_func(\%in);
	@table = &read_table_file($in{'table'}, $pfunc);
	$row = $table[$in{'idx'}];
	}

print &ui_form_start("save.cgi", "post");
print &ui_hidden("table", $in{'table'});
print &ui_hidden("idx", $in{'idx'});
print &ui_hidden("new", $in{'new'});
print &ui_hidden("before", $in{'before'});
print &ui_hidden("after", $in{'after'});

print &ui_table_start($text{$in{'tableclean'}."_header"}, "width=100%", 4);

$ffunc = $in{'tableclean'}."_form";
&$ffunc(@$row);

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("list.cgi?table=$in{'table'}", $text{$in{'tableclean'}."_return"});

