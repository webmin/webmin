#!/usr/local/bin/perl
# list_restrict.cgi
# Display usermin per-user or per-group module restrictions

require './usermin-lib.pl';
$access{'restrict'} || &error($text{'acl_ecannot'});
&ui_print_header(undef, $text{'restrict_title'}, "");

print &text('restrict_desc', "edit_acl.cgi"),"<p>\n";

@usermods = &list_usermin_usermods();
if (@usermods) {
	print "<a href='edit_restrict.cgi?new=1'>$text{'restrict_add'}",
	      "</a><br>\n";
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'restrict_who'}</b></td> ",
	      "<td><b>$text{'restrict_what'}</b></td> ",
	      "<td width=10><b>$text{'restrict_move'}</b></td> </tr>\n";
	$i = 0;
	foreach $u (@usermods) {
		print "<tr $cb>\n";
		print "<td nowrap><a href='edit_restrict.cgi?idx=$i'>",
		  $u->[0] eq "*" ? $text{'restrict_all'} :
		  $u->[0] =~ /^\@(.*)/ ?
			&text('restrict_group', "<tt>$1</tt>") :
		  $u->[0] =~ /^\// ?
			&text('restrict_file', "<tt>$u->[0]</tt>") :
			"<tt>$u->[0]</tt>","</a></td>\n";
		$mods = join(" ", map { "<tt>$_</tt>" } @{$u->[2]});
		print "<td>",!$mods ? $text{'restrict_nomods'} :
			     &text($u->[1] eq "+" ? 'restrict_plus' :
				   $u->[1] eq "-" ? 'restrict_minus' :
						    'restrict_set',
				   $mods),"</td>\n";
		print "<td>";
		if ($u eq $usermods[@usermods-1]) {
			print "<img src=images/gap.gif>";
			}
		else {
			print "<a href='move.cgi?idx=$i&down=1'>",
			      "<img src=images/down.gif border=0></a>";
			}
		if ($u eq $usermods[0]) {
			print "<img src=images/gap.gif>";
			}
		else {
			print "<a href='move.cgi?idx=$i&up=1'>",
			      "<img src=images/up.gif border=0></a>";
			}
		print "</td> </tr>\n";
		$i++;
		}
	print "</table>\n";
	}
else {
	print "<b>$text{'restrict_none'}</b><p>\n";
	}
print &ui_link("edit_restrict.cgi?new=1", $text{'restrict_add'}),"<p>\n";

&ui_print_footer("", $text{'index_return'});

