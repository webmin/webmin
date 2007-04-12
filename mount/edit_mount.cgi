#!/usr/local/bin/perl
# edit_mount.cgi
# Display a form for editing or creating a permanent or temporary mounting.

require './mount-lib.pl';
&error_setup($text{'edit_err'});
&ReadParse();
if (defined($in{index})) {
	if ($in{temp}) {
		# Edit a temporary mount, existing only in the mnttab
		@mlist = &list_mounted();
		@minfo = @{$mlist[$in{index}]};
		$mnow = 1; $msave = 0;
		}
	else {
		# Edit a permanent mount, which may or may not be currently
		# mounted.
		@mlist = &list_mounts();
		@minfo = @{$mlist[$in{index}]};
		$msave = 1; $mnow = (&get_mounted($minfo[0], $minfo[1]) >= 0);
		}
	if ($in{index} >= @mlist) {
		&error($text{'edit_egone'});
		}
	&can_edit_fs(@minfo) && !$access{'only'} ||
		&error($text{'edit_ecannot'});
	$type = $minfo[2];
	&ui_print_header(undef, $text{'edit_title'}, "");
	$newm = 0;
	}
else {
	# creating a new mount (temporary or permanent)
	$type = $in{type};
	&ui_print_header(undef, $text{'create_title'}, "");
	$newm = 1;
	}
@mmodes = &mount_modes($type);
$msave = ($mmodes[0]==0 ? 0 : $msave);
$mnow = ($mmodes[1]==0 ? $msave : $mnow);

print "<form action=\"save_mount.cgi\">\n";
print "<input name=return type=hidden value='$in{'return'}'>\n";
if (!$newm) {
	print "<input type=hidden name=old value=\"$in{index}\">\n";
	print "<input type=hidden name=temp value=\"$in{temp}\">\n";

	print "<input type=hidden name=oldmnow value=$mnow>\n";
	print "<input type=hidden name=oldmsave value=$msave>\n";
	}
print "<input type=hidden name=type value=\"$type\">\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>",&text('edit_header', &fstype_name($type)),
      "</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td>",&hlink("<b>$text{'edit_dir'}</b>", "edit_dir"), "</td>\n";
if ($type eq "swap") {
	print "<td colspan=3><i>$text{'edit_swap'}</i></b>\n";
	}
else {
	local $dir = $minfo[0] || $in{'newdir'};
	if (@access_fs == 1) {
		# Make relative to first allowed dir
		$dir =~ s/^$access_fs[0]\///;
		}
	print "<td colspan=3><input size=30 name=directory value=\"",
		$dir,"\">\n";
	if ($access{'browse'}) {
		print &file_chooser_button("directory", 1);
		}
	}
if (!$newm && (($size,$free) = &disk_space($type, $minfo[0]))) {
	print "&nbsp;" x 8;
	printf "<b>$text{'edit_size'}</b> <i>%s</i> / \n",
		&nice_size($size*1024);
	printf "<b>$text{'edit_free'}</b> <i>%s</i></td>\n",
		&nice_size($free*1024);
	}
print "</td> </tr>\n";

# Show save mount options
if ($mmodes[0] != 0 && !$access{'simple'}) {
	print "<tr> <td><b>$text{'edit_savemount'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=msave value=2 %s> $text{'edit_boot'}\n",
		$minfo[5] eq "yes" || $newm ? "checked" : "";
	if ($mmodes[0] != 1) {
		printf "<input type=radio name=msave value=1 %s> %s\n",
			$minfo[5] eq "no" ? "checked" : "", $text{'edit_save'};
		}
	if (!$newm && $mmodes[1] == 0) {
		printf "<input type=radio name=msave value=0 %s> %s\n",
			$minfo[5] eq "" && !$newm ? "checked" : "",
			$text{'edit_delete'};
		}
	else {
		printf "<input type=radio name=msave value=0 %s> %s\n",
			$minfo[5] eq "" && !$newm ? "checked" : "",
			$text{'edit_dont'};
		}
	print "</td> </tr>\n";
	}

# Show mount now options
if ($mmodes[1] == 1 && ($mmodes[3] == 0 || !$mnow) && !$access{'simple'}) {
	print "<tr> <td><b>$text{'edit_now'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=mmount value=1 %s> %s\n",
		$mnow || $newm ? "checked" : "", $text{'edit_mount'};
	if ($mmodes[0] == 0) {
		printf "<input type=radio name=mmount value=0 %s> %s\n",
			$mnow || $newm ? "" : "checked", $text{'edit_delete'};
		}
	else {
		printf "<input type=radio name=mmount value=0 %s> %s\n",
			$mnow || $newm ? "" : "checked",
			$newm ? $text{'edit_dont2'} : $text{'edit_unmount'};
		}
	print "</td> </tr>\n";
	}

# Show fsck order options
if ($mmodes[2] && !$access{'simple'}) {
	print "<tr> <td><b>$text{'edit_order'}</b></td>\n";
	printf "<td colspan=3><input type=radio name=order value=0 %s> %s\n",
		$newm || $minfo[4] == 0 ? "checked" : "", $text{'no'};
	printf "<input type=radio name=order value=1 %s> %s\n",
		$minfo[4] == 1 ? "checked" : "", $text{'edit_first'};
	printf "<input type=radio name=order value=%s %s> %s</td\n",
		$minfo[4] > 1 ? $minfo[4] : 2 , $minfo[4] > 1 ? "checked" : "",
		$text{'edit_second'};
	print "</tr>\n";
	}

# Show filesystem-specific mount source
&generate_location($type, $minfo[1] || $in{'newdev'});
print "</table></td> </tr></table><p>\n";

if (!$access{'simple'} || !defined($access{'opts'}) ||
    $access{'opts'} =~ /$type/) {
	# generate mount options
	if ($in{'advanced'}) {
		$access{'simopts'} = 0;
		print &ui_hidden("nosimopts", 1),"\n";
		}
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'edit_adv'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";
	&parse_options($type, $minfo[3]);
	&generate_options($type, $newm);
	if ($access{'simopts'}) {
		print "<tr> <td colspan=4>",
			&ui_submit($text{'edit_advanced'}, "advanced"),
			"</td> </tr>\n";
		}
	print "</table></td> </tr></table>\n";
	}

if ($access{'simple'}) {
	# buttons for mounting/unmounting
	print "<table width=100%><tr>\n";
	if ($newm) {
		print "<td><input type=submit ",
		      "value=\"$text{'edit_create'}\"></td>";
		}
	elsif ($msave && $mnow) {
		print "<td width=33%><input type=submit ",
		      "value=\"$text{'edit_save_apply'}\"></td>\n";
		if ($mmodes[1]) {
			print "<td align=center width=33%><input type=submit ",
			   "value=\"$text{'edit_umount'}\" name=umount></td>\n";
			}
		print "<td align=right width=33%><input type=submit ",
		      "value=\"$text{'edit_del_umount'}\" name=delete></td>\n";
		}
	elsif ($msave) {
		print "<td width=33%><input type=submit ",
		      "value=\"$text{'save'}\"></td>\n";
		print "<td align=center width=33%><input type=submit ",
		      "value=\"$text{'edit_mount'}\" name=mount></td>\n";
		print "<td align=right width=33%><input type=submit ",
		      "value=\"$text{'edit_delete'}\" name=delete></td>\n";
		}
	else {
		print "<td width=33%><input type=submit ",
		      "value=\"$text{'save'}\"></td>\n";
		if ($mmodes[0]) {
			print "<td align=middle width=33%><input type=submit ",
			      "value=\"$text{'edit_perm'}\" name=perm></td>\n";
			}
		print "<td align=right width=33%><input type=submit ",
		      "value=\"$text{'edit_umount'}\" name=umount></td>\n";
		}
	print "</tr></table></form>\n";
	}
else {
	# Save and other buttons
	print "<table width=100%><tr>\n";
	if ($newm) {
		print "<td><input type=submit value=\"$text{'create'}\"></td>";
		}
	elsif ($mnow && $minfo[2] ne "swap") {
		print "<td><input type=submit value=\"$text{'save'}\"></td>\n";
		print "</form><form action=../proc/index_search.cgi>\n";
		print "<input type=hidden name=mode value=3>\n";
		print "<input type=hidden name=fs value=$minfo[0]>\n";
		print "<td align=right><input type=submit ",
		      "value=\"$text{'edit_list'}\"></td>\n";
		}
	else {
		print "<td><input type=submit value=\"$text{'save'}\"></td>";
		}
	print "</tr></table></form>\n";
	}
&ui_print_footer($in{'return'}, $text{'index_return'});

