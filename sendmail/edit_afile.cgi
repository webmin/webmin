#!/usr/local/bin/perl
# edit_afile.cgi
# Display the contents of an address file

require (-r 'sendmail-lib.pl' ? './sendmail-lib.pl' :
	 -r 'qmail-lib.pl' ? './qmail-lib.pl' :
			     './postfix-lib.pl');
&ReadParse();
if (substr($in{'file'}, 0, length($access{'apath'})) ne $access{'apath'}) {
	&error(&text('afile_efile', $in{'file'}));
	}

&ui_print_header(undef, $text{'afile_title'}, "");
&open_readfile(FILE, $in{'file'});
@lines = <FILE>;
close(FILE);

print "<b>",&text('afile_desc', "<tt>$in{'file'}</tt>"),"</b><p>\n";

print "<form action=save_afile.cgi method=post enctype=multipart/form-data>\n";
print "<input type=hidden name=file value=\"$in{'file'}\">\n";
print "<input type=hidden name=num value=\"$in{'num'}\">\n";
print "<input type=hidden name=name value=\"$in{'name'}\">\n";
print "<textarea name=text rows=20 cols=80>",
	join("", @lines),"</textarea><p>\n";
print "<input type=submit value=\"$text{'save'}\"> ",
      "<input type=reset value=\"$text{'afile_undo'}\">\n";
print "</form>\n";

&ui_print_footer("edit_alias.cgi?name=$in{'name'}&num=$in{'num'}",$text{'aform_return'});

