#!/usr/local/bin/perl
# edit_user_quota.cgi
# Display a form for editing the quotas for a user on some filesystem

require './quota-lib.pl';
&ReadParse();
$u = $in{'user'}; $fs = $in{'filesys'};
&can_edit_user($u) ||
	&error(&text('euser_eallowus', $u));
$access{'ro'} && &error(&text('euser_eallowus', $u));
&can_edit_filesys($fs) ||
	&error($text{'euser_eallowfs'});
&ui_print_header(undef, $text{'euser_title'}, "", "edit_user_quota");

@quot = &user_quota($u, $fs);
$first = (@quot == 0);
$bsize = &block_size($fs);
$fsbsize = &block_size($fs, 1);

print "<table border width=100%>\n";
print "<form action=save_user_quota.cgi>\n";
print "<input type=hidden name=user value=\"$u\">\n";
print "<input type=hidden name=filesys value=\"$fs\">\n";
print "<input type=hidden name=source value=$in{'source'}>\n";
print "<tr $tb> <td colspan=2><b>",&text('euser_quotas', &html_escape($u), $fs),"</b></td> </tr>\n";
print "<tr $cb> <td width=50%><table width=100%>\n";

if (!$first) {
	if ($bsize) {
		print "<tr> <td><b>$text{'euser_kused'}</b></td> ",
		      "<td>",&nice_size($quot[0]*$bsize),"</td> </tr>\n",
		}
	else {
		print "<tr> <td><b>$text{'euser_bused'}</b></td> ",
		      "<td>$quot[0]</td> </tr>\n",
		}
	}
print "<tr> <td><b>",$bsize ? $text{'euser_sklimit'} :
			      $text{'euser_sblimit'},"</b></td>\n";
&quota_input("sblocks", $quot[1], $bsize);
print "<tr> <td><b>",$bsize ? $text{'euser_hklimit'} :
			      $text{'euser_hblimit'},"</b></td>\n";
&quota_input("hblocks", $quot[2], $bsize);
if ($access{'diskspace'}) {
	($binfo, $finfo) = &filesystem_info($fs, undef, undef, $fsbsize);
	print "<tr> <td><b>",$bsize ? $text{'euser_sdisk'} :
				      $text{'euser_bdisk'},"</b></td>\n";
	print "<td>$binfo</td> </tr>\n";
	}

print "</table></td><td width=50%><table width=100%>\n";
if (!$first) {
	print "<tr> <td><b>$text{'euser_fused'}</b></td> <td>$quot[3]</td> </tr>\n",
	}
print "<tr> <td><b>$text{'euser_sflimit'}</b></td>\n";
&quota_input("sfiles", $quot[4]);
print "<tr> <td><b>$text{'euser_hflimit'}</b></td>\n";
&quota_input("hfiles", $quot[5]);
if ($access{'diskspace'}) {
	print "<tr> <td><b>$text{'euser_fdisk'}</b></td>\n";
	print "<td>$finfo</td> </tr>\n";
	}

print "</table></td></tr></table>\n";

print "<table width=100%><tr>\n";
print "<td><input type=submit value=$text{'euser_update'}></td>\n";
print "</form><form action=user_filesys.cgi>\n";
print "<input type=hidden name=user value=\"$u\">\n";
print "<td align=right><input type=submit value=\"$text{'euser_listall'}\"></td>\n";
print "</form></tr></table>\n";

if ($in{'source'}) {
	&ui_print_footer("user_filesys.cgi?user=".&urlize($u), $text{'euser_freturn'});
	}
else {
	&ui_print_footer("list_users.cgi?dir=".&urlize($fs), $text{'euser_ureturn'});
	}


