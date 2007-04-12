#!/usr/local/bin/perl
# list_headeracc.cgi
# Display all header access control restrictions

require './squid-lib.pl';
$access{'headeracc'} || &error($text{'header_ecannot'});
&ui_print_header(undef, $text{'header_title'}, "", "list_headeracc", 0, 0, 0, &restart_button());
$conf = &get_config();

@headeracc = &find_config("header_access", $conf);
if (@headeracc) {
	print "<a href='edit_headeracc.cgi?new=1'>$text{'header_add'}</a>\n";
	print "<table border>\n";
	print "<tr $tb> <td><b>$text{'header_name'}</b></td> ",
	      "<td><b>$text{'header_act'}</b></td> ",
	      "<td><b>$text{'header_acls'}</b></td> ",
	      "<td width=10%><b>$text{'eacl_move'}</b></td> </tr>\n";
	$hc = 0;
	foreach $h (@headeracc) {
		@v = @{$h->{'values'}};
		print "<tr $cb>\n";
		print "<td><a href='edit_headeracc.cgi?index=$h->{'index'}'>",
		      "$v[0]</a></td>\n";
		print "<td>",$v[1] eq 'allow' ?  $text{'eacl_allow'} :
				$text{'eacl_deny'},"</td>\n";
		print "<td>",join(" ", @v[2..$#v]),"</td>\n";
		print "<td>\n";
		if ($hc != @headeracc-1) {
			print "<a href=\"move_headeracc.cgi?$hc+1\">",
			      "<img src=images/down.gif border=0></a>";
			}
		else { print "<img src=images/gap.gif>"; }
		if ($hc != 0) {
			print "<a href=\"move_headeracc.cgi?$hc+-1\">",
			      "<img src=images/up.gif border=0></a>";
			}
		print "</td></tr>\n";
		print "</tr>\n";
		$hc++;
		}
	print "</table>\n";
	}
else {
	print "<p>$text{'header_none'}<p>\n";
	}
print "<a href='edit_headeracc.cgi?new=1'>$text{'header_add'}</a><br>\n";

&ui_print_footer("", $text{'index_return'});

