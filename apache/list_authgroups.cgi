#!/usr/local/bin/perl
# list_authgroups.cgi
# Displays a list of groups and their members

require './apache-lib.pl';
require './auth-lib.pl';

$conf = &get_config();
&ReadParse();
&allowed_auth_file($in{'file'}) ||
	&error(&text('authg_ecannot', $in{'file'}));
$desc = &text('authg_header', "<tt>$in{'file'}</tt>");
&ui_print_header($desc, $text{'authg_title'}, "");
$f = &server_root($in{'file'}, $conf);

@groups = sort { $a->{'name'} cmp $b->{'name'} } &list_authgroups($in{'file'});
if (@groups) {
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>",&text('authg_header2', "<tt>$f</tt>"),
	      "</b></td></tr>\n";
	print "<tr $cb> <td><table width=100%>\n";
	print "<tr> <td><b>$text{'authg_group'}</b></td> ",
	      "<td><b>$text{'authg_mems'}</b></td> </tr>\n";
	for($i=0; $i<@groups; $i++) {
		$g = $groups[$i]->{'group'};
		@m = @{$groups[$i]->{'members'}};
		if (@m > 15) { @m = @m[0..14]; }
        print "<tr><td>";
        print &ui_link("edit_authgroup.cgi?group=$g&".
            "file=".&urlize($f)."&url=".&urlize(&this_url()), $g);
        print "</td>";
		printf "<td>%s</td></tr>\n",
			@m ? join(" , ", @m) : "<i>None</i>";
		}
	print "</table></td></tr></table>\n";
	}
else {
	print "<b>",&text('authg_none', "<tt>$f</tt>"),"</b><p>\n";
	}
print &ui_link("edit_authgroup.cgi?file=".
        &urlize($f)."&url=".&urlize(&this_url()), $text{'authg_add'});
print "<p>\n";

&ui_print_footer($in{'url'}, $text{'auth_return'});

