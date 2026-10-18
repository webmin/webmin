#!/usr/local/bin/perl
# search_form.cgi
# Display a form for searching a mailbox

require './mailboxes-lib.pl';
&ReadParse();
&can_user($in{'user'}) || &error($text{'mail_ecannot'});

@folders = &list_user_folders_sorted($in{'user'});
($folder) = grep { $_->{'index'} == $in{'folder'} } @folders;
&ui_print_header(undef, $text{'sform_title'}, "", undef, 0, 0, undef,
	&folder_link($in{'user'}, $folder));

# Escape localized labels before inserting them into JavaScript strings.
my $sform_larger_js = &quote_javascript($text{'sform_larger'});
my $sform_smaller_js = &quote_javascript($text{'sform_smaller'});
my $sform_neg0_js = &quote_javascript($text{'sform_neg0'});
my $sform_neg1_js = &quote_javascript($text{'sform_neg1'});
print <<EOF;
<script>
function set_neg(mode, negfield)
{
if (mode == "size") {
	negfield.options[0].text = "$sform_larger_js";
	negfield.options[1].text = "$sform_smaller_js";
	}
else {
	negfield.options[0].text = "$sform_neg0_js";
	negfield.options[1].text = "$sform_neg1_js";
	}
}
</script>
EOF

# Start of form
print &ui_form_start("mail_search.cgi");
print &ui_hidden("user", $in{'user'});
print &ui_hidden("dom", $in{'dom'});
print &ui_hidden("ofolder", $in{'folder'});
print &ui_table_start($text{'sform_header'}, "width=100%", 2);

# And/or mode
print &ui_table_row($text{'sform_andmode'},
		&ui_radio("and", 1, [ [ 1, $text{'sform_and'} ],
				      [ 0, $text{'sform_or'} ] ]));

# Criteria table
$ctable = &ui_columns_start([ ], 50, 1);
for($i=0; $i<=4; $i++) {
	local @cols;
	push(@cols, $text{'sform_where'});
	push(@cols, &ui_select("field_$i", undef,
			[ [ undef, "&nbsp;" ],
			  map { [ $_, $_ eq 'all' ? $text{'sform_allmsg'}
						  : $text{"sform_".$_} ] }
			      ( 'from', 'subject', 'to', 'cc', 'date',
				'body', 'headers', 'all', 'size') ],
			1, 0, 0, undef, "onChange='set_neg(value, form.neg_$i)'"));

	push(@cols, &ui_select("neg_$i", 0,
			[ [ 0, $text{'sform_neg0'} ],
			  [ 1, $text{'sform_neg1'} ] ]));

	push(@cols, $text{'sform_text'});
	push(@cols, &ui_textbox("what_$i", undef, 30));
	$ctable .= &ui_columns_row(\@cols, [ map { "nowrap" } @cols ]);
	}
$ctable .= &ui_columns_end();
print &ui_table_row(" ", $ctable);

# Folder to search
print &ui_table_row($text{'sform_folder2'},
	&folder_select(\@folders, $folder, "folder",
		       [ [ -1, $text{'sform_all'} ] ]));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'sform_ok'} ] ]);

&ui_print_footer("list_mail.cgi?folder=$in{'folder'}&user=".
		  &urlize($in{'user'})."&dom=$in{'dom'}", $text{'mail_return'},
		 &user_list_link(), $text{'index_return'});

