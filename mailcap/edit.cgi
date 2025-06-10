#!/usr/local/bin/perl
# Show a form for editing or creating a mailcap entry

require './mailcap-lib.pl';
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'edit_title1'}, "");
	$mailcap = { 'enabled' => 1 };
	}
else {
	&ui_print_header(undef, $text{'edit_title2'}, "");
	@mailcap = &list_mailcap();
	($mailcap) = grep { $_->{'index'} == $in{'index'} } @mailcap;
	$mailcap || &error($text{'edit_egone'});
	}
$args = $mailcap->{'args'};

# Form header
print &ui_form_start("save.cgi", "post");
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_hidden("index", $in{'index'}),"\n";
print &ui_table_start($text{'edit_header'}, "width=100%", 2);

# MIME type, program and description fields
print &ui_table_row($text{'edit_type'},
		    &ui_textbox("type", $mailcap->{'type'}, 30));
print &ui_table_row($text{'edit_enabled'},
		    &ui_yesno_radio("enabled", int($mailcap->{'enabled'})));
print &ui_table_row($text{'edit_program'},
		    &ui_textbox("program", $mailcap->{'program'}, 70));
if ($mailcap->{'cmt'} =~ /\n/) {
	# Multi-line comment from file comments
	print &ui_table_row($text{'edit_cmt'},
		    &ui_textarea("cmt", $mailcap->{'cmt'}, 3, 70, "off"));
	}
else {
	# Single line comment from file comment
	print &ui_table_row($text{'edit_cmt'},
		    &ui_textbox("cmt", $mailcap->{'cmt'}, 70));
	}

# Other options
print &ui_table_hr();

print &ui_table_row($text{'edit_test'},
    &ui_opt_textbox("test", $args->{'test'}, 50, $text{'edit_none'}));

print &ui_table_row($text{'edit_term'},
	&ui_yesno_radio("term", defined($args->{'needsterminal'}) ? 1 : 0));
print &ui_table_row($text{'edit_copious'},
	&ui_yesno_radio("copious", defined($args->{'copiousoutput'}) ? 1 : 0));

print &ui_table_row($text{'edit_desc'},
    &ui_opt_textbox("desc", $args->{'description'}, 50, $text{'edit_none'}));

# Form footer
print &ui_table_end();
print &ui_form_end([
	$in{'new'} ? ( [ "create", $text{'create'} ] )
		   : ( [ "save", $text{'save'} ],
		       [ "delete", $text{'delete'} ] ) ]);

&ui_print_footer("", $text{'index_return'});

