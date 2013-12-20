#!/usr/local/bin/perl
# list_authusers.cgi
# Displays a list of users from a text file

require './apache-lib.pl';
require './auth-lib.pl';

$conf = &get_config();
&ReadParse();
&allowed_auth_file($in{'file'}) ||
	&error(&text('authu_ecannot', $in{'file'}));
$desc = &text('authu_header', "<tt>$in{'file'}</tt>");
&ui_print_header($desc, $text{'authu_title'}, "");
$f = &server_root($in{'file'}, $conf);

@users = sort { $a cmp $b } &list_authusers($f);
if (@users) {
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>",&text('authu_header2', "<tt>$f</tt>"),
	      "</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";
	for($i=0; $i<@users; $i++) {
		$u = $users[$i];
		if ($i%4 == 0) { print "<tr>\n"; }
        print "<td width='25%'>";
        print &ui_link("edit_authuser.cgi?user=$u&file=".&urlize($f)."&url=".&urlize(&this_url()), $u);
        print "</td>";
		if ($i%4 == 3) { print "</tr>\n"; }
		}
	while($i++%4) { print "<td width=25%></td>\n"; }
	print "</table></td></tr></table>\n";
	}
else {
	print "<b>",&text('authu_none', "<tt>$f</tt>"),"</b><p>\n";
	}
print &ui_link("edit_authuser.cgi?file=".&urlize($f)."&url=".&urlize(&this_url()), $text{'authu_add'});
print "<p>\n";

print &ui_hr();
$s = $config{"sync_$f"};
print "<form action=save_sync.cgi>\n";
print "$text{'authu_sync'} <p>\n";
print "<input type=hidden name=file value='$f'>\n";
print "<input type=hidden name=url value='$in{'url'}'>\n";
printf "<input type=checkbox name=sync value=create %s> %s<br>\n",
	$s =~ /create/ ? 'checked' : '', $text{'authu_screate'};
printf "<input type=checkbox name=sync value=modify %s> %s<br>\n",
	$s =~ /modify/ ? 'checked' : '', $text{'authu_smodify'};
printf "<input type=checkbox name=sync value=delete %s> %s<br>\n",
	$s =~ /delete/ ? 'checked' : '', $text{'authu_sdelete'};
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer($in{'url'}, $text{'auth_return'});

