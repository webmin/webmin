#!/usr/local/bin/perl
# edit_pam.cgi
# Display the modules for some PAM service

require './pam-lib.pl';
&ReadParse();

&ui_print_header(undef, $text{'edit_title'}, "");
@pams = &get_pam_config();
$pam = $pams[$in{'idx'}];

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td width=10%><b>$text{'edit_name'}</b></td>\n";
$t = $text{'desc_'.$pam->{'name'}};
print "<td><tt>",&html_escape($pam->{'name'}),"</tt> ",
		$pam->{'desc'} ? "($pam->{'desc'})" :
		$t ? "($t)" : "","</td>\n";
print "</tr>\n";

foreach $t ('auth', 'account', 'session', 'password') {
	print "<tr> <td colspan=2>\n";
	print "<form action=edit_mod.cgi><table border width=100%>\n";
	print "<tr $tb> <td><b>",$text{"edit_header_$t"},"</b></td> </tr>\n";
	print "<tr $cb> <td>\n";

	local @mods = grep { $_->{'type'} eq $t } @{$pam->{'mods'}};
	print "<table width=100%>\n";
	if (@mods) {
		print "<tr $cb> <td width=20%><b>$text{'edit_mod'}</b></td> ",
		      "<td width=35%><b>$text{'edit_desc'}</b></td> ",
		      "<td width=20%><b>$text{'edit_control'}</b></td> ",
		      "<td width=20%><b>$text{'edit_args'}</b></td> ",
		      "<td width=5%><b>$text{'edit_move'}</b></td> </tr>\n";
		}
	else {
		print "<tr> <td colspan=5><b>$text{'edit_none'}",
		      "</b></td> </tr>\n";
		}
	foreach $m (@mods) {
		local $mn = $m->{'module'};
		$mn =~ s/^.*\///;
		print "<tr $cb>\n";
		print "<td><a href='edit_mod.cgi?idx=$pam->{'index'}&",
		      "midx=$m->{'index'}'>$mn</a></td>\n";
		print "<td>",$text{$mn} ? $text{$mn} : "<br>","</td>\n";
		print "<td>",$text{'control_'.$m->{'control'}},"</td>\n";
		print "<td>",$m->{'args'} ? $m->{'args'} : "<br>","</td>\n";
		print "<td>";
		if ($m eq $mods[$#mods]) {
			print "<img src=images/gap.gif>";
			}
		else {
			print "<a href='move.cgi?idx=$pam->{'index'}&",
			      "midx=$m->{'index'}&down=1'><img ",
			      "src=images/down.gif border=0></a>";
			}
		if ($m eq $mods[0]) {
			print "<img src=images/gap.gif>";
			}
		else {
			print "<a href='move.cgi?idx=$pam->{'index'}&",
			      "midx=$m->{'index'}&up=1'><img ",
			      "src=images/up.gif border=0></a>";
			}
		print "</tr>\n";
		}
	print "</table>\n";
	print "<input type=hidden name=idx value='$in{'idx'}'>\n";
	print "<input type=hidden name=type value='$t'>\n";
	print "<input type=submit value='$text{'edit_addmod'}'>\n";
	print "<select name=module>\n";
	foreach $m (sort { $a cmp $b } &list_modules()) {
		printf "<option value=%s>%s\n",
			$m, $text{$m} ? "$m ($text{$m})" : $m;
		}
	print "</select></td> </tr>\n";
	print "</table></form></td></tr>\n";
	}

print "<form action=delete_pam.cgi>\n";
print "</table></td></tr></table>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<input type=submit value='$text{'edit_delete'}'>\n";
print "</form>\n";

&ui_print_footer("", $text{'index_return'});

