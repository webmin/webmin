#!/usr/local/bin/perl
# edit_afile.cgi
# Display the contents of an address file

require (-r 'sendmail-lib.pl' ? './sendmail-lib.pl' :
	 -r 'qmail-lib.pl' ? './qmail-lib.pl' :
			     './postfix-lib.pl');
&ReadParse();

# Needs permission for address file aliases, and for the file's directory
if (!&can_edit_alias_files(2, $in{'file'}) ||
    !&is_under_directory($access{'apath'}, $in{'file'})) {
	&error(&text('afile_efile', &html_escape($in{'file'})));
	}

&ui_print_header(undef, $text{'afile_title'}, "");
&open_readfile(FILE, $in{'file'});
@lines = <FILE>;
close(FILE);

print "<b>",&text('afile_desc',
		  "<tt>".&html_escape($in{'file'})."</tt>"),"</b><p>\n";

print "<form action=save_afile.cgi method=post enctype=multipart/form-data>\n";
print &ui_hidden("file", $in{'file'}),"\n";
print &ui_hidden("num", $in{'num'}),"\n";
print &ui_hidden("name", $in{'name'}),"\n";
print "<textarea name=text rows=20 cols=80>",
	&html_escape(join("", @lines)),"</textarea><p>\n";
print "<input type=submit value=\"$text{'save'}\"> ",
      "<input type=reset value=\"$text{'afile_undo'}\">\n";
print "</form>\n";

&ui_print_footer("edit_alias.cgi?name=".&urlize($in{'name'}).
		 "&num=".&urlize($in{'num'}), $text{'aform_return'});

