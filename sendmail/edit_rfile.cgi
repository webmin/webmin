#!/usr/local/bin/perl
# edit_rfile.cgi
# Display the contents of an autoreply file

require (-r 'sendmail-lib.pl' ? './sendmail-lib.pl' :
	 -r 'qmail-lib.pl' ? './qmail-lib.pl' :
			     './postfix-lib.pl');
&ReadParse();

# Needs permission for autoreply aliases, and for the file's directory
if (!&can_edit_alias_files(5) ||
    !&is_under_directory($access{'apath'}, $in{'file'})) {
	&error(&text('rfile_efile', &html_escape($in{'file'})));
	}

&ui_print_header(undef, $text{'rfile_title'}, "");
&open_readfile(FILE, $in{'file'});
while(<FILE>) {
	if (/^Reply-Tracking:\s*(.*)/) {
		$replies = $1;
		}
	elsif (/^Reply-Period:\s*(.*)/) {
		$period = $1;
		}
	elsif (/^No-Autoreply:\s*(.*)/) {
		$no_autoreply = $1;
		}
	elsif (/^No-Autoreply-Regexp:\s*(.*)/) {
		push(@no_regexp, $1);
		}
	elsif (/^From:\s*(.*)/) {
		$from = $1;
		}
	else {
		push(@lines, $_);
		}
	}
close(FILE);

print &text('rfile_desc', "<tt>".&html_escape($in{'file'})."</tt>"),"<p>\n";
print "$text{'rfile_desc2'}<p>\n";

print "<form action=save_rfile.cgi method=post enctype=multipart/form-data>\n";
print &ui_hidden("file", $in{'file'}),"\n";
print &ui_hidden("num", $in{'num'}),"\n";
print &ui_hidden("name", $in{'name'}),"\n";
print "<textarea name=text rows=20 cols=80 $config{'wrap_mode'}>",
	&html_escape(join("", @lines)),"</textarea>\n";

print "<table>\n";

# Show From: address
print "<tr> <td>$text{'rfile_from'}</td>\n";
printf "<td><input type=radio name=from_def value=1 %s> %s\n",
	$from eq '' ? "checked" : "", $text{'rfile_auto'};
printf "<input type=radio name=from_def value=0 %s>\n",
	$from eq '' ? "" :"checked";
printf "<input name=from size=30 value='%s'></td> </tr>\n",
	&quote_escape($from, "'");
print "<tr> <td></td> <td><font size=-1>$text{'rfile_fromdesc'}</font></td> </tr>\n";

# Show reply-tracking file
print "<tr> <td>$text{'rfile_replies'}</td>\n";
printf "<td><input type=radio name=replies_def value=1 %s> %s\n",
	$replies eq '' ? "checked" : "", $text{'rfile_none'};
printf "<input type=radio name=replies_def value=0 %s> %s\n",
	$replies eq '' ? "" :"checked", $text{'rfile_file'};
printf "<input name=replies size=30 value='%s'> %s</td> </tr>\n",
	&quote_escape($replies, "'"), &file_chooser_button("replies");
print "&nbsp;" x 3;

# Show reply-tracking period
print "<tr> <td>&nbsp;&nbsp;&nbsp;$text{'rfile_period'}</td>\n";
printf "<td><input type=radio name=period_def value=1 %s> %s\n",
	$period eq '' ? "checked" : "", $text{'rfile_default'};
printf "<input type=radio name=period_def value=0 %s>\n",
	$period eq '' ? "" :"checked";
printf "<input name=period size=5 value='%s'> %s</td> </tr>\n",
	&quote_escape($period, "'"), $text{'rfile_secs'};

# Show people to not autoreply to
print "<tr> <td>$text{'rfile_no_autoreply'}</td>\n";
printf "<td><input name=no_autoreply size=40 value='%s'></td> </tr>\n",
	&quote_escape($no_autoreply, "'");

# Show regexps to not autoreply to
print "<tr> <td>$text{'rfile_no_regexp'}</td>\n";
print "<td>",&ui_textarea("no_regexp", join("\n", @no_regexp), 3, 40),"</td> </tr>\n";

print "</table>\n";

print "<input type=submit value=\"$text{'save'}\"> ",
      "<input type=reset value=\"$text{'rfile_undo'}\">\n";
print "</form>\n";

&ui_print_footer("edit_alias.cgi?name=".&urlize($in{'name'}).
		 "&num=".&urlize($in{'num'}), $text{'aform_return'});

