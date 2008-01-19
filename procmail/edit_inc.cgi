#!/usr/local/bin/perl
# edit_inc.cgi
# Edit an include file line

require './procmail-lib.pl';
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'inc_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'inc_title2'}, "");
	@conf = &get_procmailrc();
	$inc = $conf[$in{'idx'}];
	}

print &ui_form_start("save_inc.cgi");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});
print &ui_table_start($text{'inc_header'}, "width=100%", 2);

# Included file
print &ui_table_row($text{'inc_inc'},
	&ui_textbox("inc", $inc->{'include'}, 60)." ".
	&file_chooser_button("inc"));

# Show save buttons
print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

