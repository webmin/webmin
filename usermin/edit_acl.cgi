#!/usr/local/bin/perl
# edit_acl.cgi
# Choose visible usermin modules

require './usermin-lib.pl';
$access{'acl'} || &error($text{'acl_ecannot'});
&ui_print_header(undef, $text{'acl_title'}, "");

&read_usermin_acl(\%acl);
print "$text{'acl_desc'}<p>\n";
print "<form action=save_acl.cgi>\n";
print "<table width=100%>\n";
@mods = &list_modules();
foreach $m (@mods) {
	print "<tr>\n" if ($i % 3 == 0);
	printf "<td width=33%%><input type=checkbox name=mod value=%s %s> %s</td>\n",
		$m->{'dir'}, $acl{'user',$m->{'dir'}} ? 'checked' : '',
		$m->{'desc'};
	print "</tr>\n" if ($i % 3 == 2);
	$i++;
	}
print "</table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

