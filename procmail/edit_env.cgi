#!/usr/local/bin/perl
# edit_env.cgi
# Edit an environment variable setting

require './procmail-lib.pl';
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'env_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'env_title2'}, "");
	@conf = &get_procmailrc();
	$env = $conf[$in{'idx'}];
	}

print "<form action=save_env.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'env_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'env_name'}</b></td>\n";
printf "<td><input name=name size=60 value='%s'></td> </tr>\n",
	&html_escape($env->{'name'});

print "<tr> <td valign=top><b>$text{'env_value'}</b></td>\n";
if ($env->{'value'} =~ /\n/) {
	print "<td><textarea name=value rows=4 cols=60>",
		&html_escape($env->{'value'}),"</textarea></td> </tr>\n";
	}
else {
	printf "<td><input name=value size=60 value='%s'></td> </tr>\n",
		&html_escape($env->{'value'});
	}

print "</table></td></tr></table>\n";

# Show save buttons
print "<table width=100%><tr>\n";
if ($in{'new'}) {
	print "<td><input type=submit value='$text{'create'}'></td>\n";
	}
else {
	print "<td><input type=submit value='$text{'save'}'></td>\n";
	print "<td align=right><input type=submit name=delete ",
	      "value='$text{'delete'}'></td>\n";
	}
print "</tr></table></form>\n";

&ui_print_footer("", $text{'index_return'});

