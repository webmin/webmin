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

# Start of the form
print &ui_form_start("save_mount.cgi", "post");
print &ui_hidden("return", $in{'return'});
if (!$newm) {
	print &ui_hidden("old", $in{'index'});
	print &ui_hidden("temp", $in{'temp'});
	print &ui_hidden("oldmnow", $mnow);
	print &ui_hidden("oldmsave", $msave);
	}
print &ui_hidden("type", $in{'type'});
print &ui_table_start(&text('edit_header', &fstype_name($type)),
		      "width=100%", 2);

# Mount point
if ($type eq "swap") {
	$mfield = "<i>$text{'edit_swap'}</i>";
	}
else {
	local $dir = $minfo[0] || $in{'newdir'};
	if (@access_fs == 1) {
		# Make relative to first allowed dir
		$dir =~ s/^$access_fs[0]\///;
		}
	$mfield = &ui_textbox("directory", $dir, 40);
	if ($access{'browse'}) {
		$mfield .= " ".&file_chooser_button("directory", 1);
		}
	}
print &ui_table_row(&hlink($text{'edit_dir'}, "edit_dir"),
		    $mfield);

# Total and free space
if (!$newm && (($size,$free) = &disk_space($type, $minfo[0]))) {
	print &ui_table_row($text{'edit_usage'},
		"<b>$text{'edit_size'}</b> ",
		&nice_size($size*1024)," ",
		"<b>$text{'edit_free'}</b> ",
		&nice_size($free*1024));
	}

# Show save mount options
if ($mmodes[0] != 0 && !$access{'simple'}) {
	@opts = ( [ 2, $text{'edit_boot'} ] );
	if ($mmodes[0] != 1) {
		push(@opts, [ 1, $text{'edit_save'} ]);
		}
	if (!$newm && $mmodes[1] == 0) {
		push(@opts, [ 0, $text{'edit_delete'} ]);
		}
	else {
		push(@opts, [ 0, $text{'edit_dont'} ]);
		}
	print &ui_table_row($text{'edit_savemount'},
		&ui_radio("msave", $minfo[5] eq "yes" || $newm ? 2 :
				   $minfo[5] eq "no" ? 1 :
				   $minfo[5] eq "" && !$newm ? 0 : undef,
			  \@opts));
	}

# Show mount now options
if ($mmodes[1] == 1 && ($mmodes[3] == 0 || !$mnow) && !$access{'simple'}) {
	print &ui_table_row($text{'edit_now'},
		&ui_radio("mmount", $mnow || $newm ? 1 : 0,
			  [ [ 1, $text{'edit_mount'} ],
			    [ 0, $mmodes[0] == 0 ? $text{'edit_delete'} :
				 $newm ? $text{'edit_dont2'} :
					 $text{'edit_unmount'} ] ]));
	}

# Show fsck order options
if ($mmodes[2] && !$access{'simple'}) {
	$second = $minfo[4] > 1 ? $minfo[4] : 2;
	print &ui_table_row($text{'edit_order'},
		&ui_radio("order", $newm || $minfo[4] == 0 ? 0 :
				   $minfo[4] == 1 ? 1 :
				   $second,
			  [ [ 0, $text{'no'} ],
			    [ 1, $text{'edit_first'} ],
			    [ $second, $text{'edit_second'} ] ]));
	}

# Show filesystem-specific mount source
&generate_location($type, $minfo[1] || $in{'newdev'});
print &ui_table_end();

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

