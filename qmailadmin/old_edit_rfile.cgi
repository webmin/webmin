#!/usr/local/bin/perl
# edit_rfile.cgi
# Display the contents of an autoreply file

require './qmail-lib.pl';
&ReadParse();

&ui_print_header(undef, $text{'rfile_title'}, "");
open(FILE, $in{'file'});
while(<FILE>) {
	if (/^Reply-Tracking:\s*(.*)/) {
		$replies = $1;
		}
	elsif (/^Reply-Period:\s*(.*)/) {
		$period = $1;
		}
	else {
		push(@lines, $_);
		}
	}
close(FILE);

print "<b>",&text('rfile_desc', "<tt>$in{'file'}</tt>"),"</b><p>\n";
print "$text{'rfile_desc2'}<p>\n";

print "<form action=save_rfile.cgi method=post enctype=multipart/form-data>\n";
print "<input type=hidden name=file value=\"$in{'file'}\">\n";
print "<input type=hidden name=name value=\"$in{'name'}\">\n";
print "<textarea name=text rows=20 cols=80 $config{'wrap_mode'}>",
	join("", @lines),"</textarea><p>\n";

print $text{'rfile_replies'},"\n";
printf "<input type=radio name=replies_def value=1 %s> %s\n",
	$replies eq '' ? "checked" : "", $text{'rfile_none'};
printf "<input type=radio name=replies_def value=0 %s> %s\n",
	$replies eq '' ? "" :"checked", $text{'rfile_file'};
printf "<input name=replies size=30 value='%s'> %s<br>\n",
	$replies, &file_chooser_button("replies");
print "&nbsp;" x 3;
print $text{'rfile_period'},"\n";
printf "<input type=radio name=period_def value=1 %s> %s\n",
	$period eq '' ? "checked" : "", $text{'rfile_default'};
printf "<input type=radio name=period_def value=0 %s>\n",
	$period eq '' ? "" :"checked";
printf "<input name=period size=5 value='%s'> %s<p>\n",
	$period, $text{'rfile_secs'};

print "<input type=submit value=\"$text{'save'}\"> ",
      "<input type=reset value=\"$text{'rfile_undo'}\">\n";
print "</form>\n";

&ui_print_footer("edit_alias.cgi?name=$in{'name'}", $text{'aform_return'});

