#!/usr/local/bin/perl
# edit_lang.cgi
# Language config form

require './usermin-lib.pl';
$access{'lang'} || &error($text{'acl_ecannot'});
&ui_print_header(undef, $text{'lang_title'}, "");

&get_usermin_config(\%uconfig);
print $text{'lang_intro'},"<p>\n";

print "<form action=change_lang.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'lang_title2'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

$clang = $uconfig{'lang'} ? $uconfig{'lang'} : $default_lang;
print "<tr> <td><b>$webmin::text{'lang_lang'}</b></td>\n";
print "<td><select name=lang>\n";
foreach $l (&list_languages()) {
	printf "<option value=%s %s>%s (%s)\n",
		$l->{'lang'},
		$clang eq $l->{'lang'} ? 'selected' : '',
		$l->{'desc'}, uc($l->{'lang'});
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$webmin::text{'lang_accept'}</b></td>\n";
printf "<td><input type=radio name=acceptlang value=1 %s> %s\n",
	$uconfig{'acceptlang'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=acceptlang value=0 %s> %s</td> </tr>\n",
	$uconfig{'acceptlang'} ? "" : "checked", $text{'no'};

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$webmin::text{'lang_ok'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

