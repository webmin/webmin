#!/usr/local/bin/perl
# edit_action.cgi
# Edit or create a bootup action. Existing actions can either be in the
# init.d directory (and linked to from the appropriate runlevels), or
# just plain runlevel files

require './init-lib.pl';
%access = &get_module_acl();
$access{'bootup'} || &error($text{'edit_ecannot'});

$ty = $ARGV[0];
if ($ty == 0) {
	# Editing an action in init.d, linked to from various runlevels
	$ac = $ARGV[1];
	&ui_print_header(undef, $text{'edit_title'}, "");
	$file = &action_filename($ac);
	open(FILE, $file);
	while(<FILE>) {
		$data .= $_;
		if (/^\s*(['"]?)([a-z]+)\1\)/i) {
			$hasarg{$2}++;
			}
		}
	close(FILE);
	}
elsif ($ty == 1) {
	# Editing an action in one of the runlevels
	$rl = $ARGV[1];
	$num = $ARGV[2];
	$ac = $ARGV[3];
	$inode = $ARGV[4];
	$ss = $ARGV[5];
	&ui_print_header(undef, $text{'edit_title'}, "");
	$file = &runlevel_filename($rl, $ss, $num, $ac);
	$data = `cat $file`;
	}
else {
	# Creating a new action in init.d
	&ui_print_header(undef, $text{'create_title'}, "");
	}

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_details'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";
print "<form method=post action=save_action.cgi enctype=multipart/form-data>\n";
print "<input type=hidden name=type value=$ty>\n";
if ($ty != 2) {
	print "<input type=hidden name=old value=\"$ac\">\n";
	if ($ty == 1) {
		print "<input type=hidden name=runlevel value=\"$rl\">\n";
		print "<input type=hidden name=startstop value=\"$ss\">\n";
		print "<input type=hidden name=number value=\"$num\">\n";
		}
	}
print "<tr> <td><b>$text{'edit_name'}</b></td>\n";
if ($ac =~ /^\// || $access{'bootup'} == 2) {
	print "<td><tt>$ac</tt></td> </tr>\n";
	print "<input type=hidden name=name value=\"$ac\">\n";
	print "<input type=hidden name=extra value=1>\n";
	}
else {
	print "<td><input size=20 name=name value=\"$ac\"></td> </tr>\n";
	}

$fs = "<font size=-1>"; $fe = "</font>";
if ($ty == 2) {
	# Display fields for a template
	print "<tr> <td valign=top><b>$text{'edit_desc'}</b></td>\n";
	print "<td>$fs<textarea rows=2 cols=80 name=desc>",
	      "</textarea>$fe</td> </tr>\n";

	if ($config{'start_stop_msg'}) {
		print "<tr> <td><b>$text{'edit_startmsg'}</b></td>\n";
		print "<td><input name=start_msg size=40></td> </tr>\n";

		print "<tr> <td><b>$text{'edit_stopmsg'}</b></td>\n";
		print "<td><input name=stop_msg size=40></td> </tr>\n";
		}

	print "<tr> <td valign=top><b>$text{'edit_start'}</b></td>\n";
	print "<td>$fs<textarea rows=5 cols=80 name=start>",
	      "</textarea>$fe</td> </tr>\n";

	print "<tr> <td valign=top><b>$text{'edit_stop'}</b></td>\n";
	print "<td>$fs<textarea rows=5 cols=80 name=stop>",
	      "</textarea>$fe</td> </tr>\n";
	}
elsif ($access{'bootup'} == 2) {
	# Just show current script
	print "<tr> <td valign=top><b>$text{'edit_script'}</b></td>\n";
	print "<td>$fs<pre>",&html_escape($data),"</pre>$fe</td> </tr>\n";
	}
else {
	# Allow direct editing of the script
	print "<tr> <td valign=top><b>$text{'edit_script'}</b></td>\n";
	print "<td>$fs<textarea rows=15 cols=80 name=data>",&html_escape($data),
	      "</textarea>$fe</td> </tr>\n";
	}

if ($ty == 1 && $access{'bootup'} == 1) {
	# Display a message about the script being bogus
	print "</table></td></tr></table><p>\n";
	print "<b>",&text("edit_bad$ss", $rl),"</b><br>\n";
	print "<a href=\"fix_action.cgi?$rl+$ss+$num+$ac\">",
	      "$text{'edit_fix'}</a>. <p>\n";
	}
elsif (!$config{'expert'} || $access{'bootup'} == 2) {
	# Just tell the user if this action is started at boot time
	local $boot = 0;
	print "<tr> <td><b>$text{'edit_boot'}</b></td>\n";
	if ($ty == 0) {
		local @boot = &get_inittab_runlevel();
		foreach $s (&action_levels('S', $ac)) {
			local ($l, $p) = split(/\s+/, $s);
			$boot = 1 if (&indexof($l, @boot) >= 0);
			}
		if ($boot && $config{'daemons_dir'} &&
		    &read_env_file("$config{'daemons_dir'}/$ac", \%daemon)) {
			$boot = lc($daemon{'ONBOOT'}) eq 'yes' ? 1 : 0;
			}
		print "<input type=hidden name=oldboot value='$boot'>\n";
		}
	if ($access{'bootup'} == 1) {
		printf "<td><input name=boot type=radio value=1 %s> %s\n",
			$boot || $ty == 2 ? 'checked' : '', $text{'yes'};
		printf "<input name=boot type=radio value=0 %s> %s\n",
			$boot || $ty == 2 ? '' : 'checked', $text{'no'};
		}
	else {
		print "<td>",$boot || $ty == 2 ? $text{'yes'} : $text{'no'};
		}
	if ($hasarg{'status'} && $config{'status_check'}) {
		# Show if action is currently running
		$out = `$file status </dev/null 2>/dev/null`;
		print "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;",
		      "<b>$text{'edit_status'}</b>&nbsp;&nbsp;\n";
		if ($out =~ /running/i) {
			print $text{'yes'};
			}
		elsif ($out =~ /stopped/i) {
			print "<font color=#ff0000>$text{'no'}</font>";
			}
		else {
			print "<i>$text{'edit_unknown'}</i>";
			}
		}
	print "</td></tr> </table></td></tr></table>\n";
	}
else {
	if ($config{'daemons_dir'} && $ac &&
	    &read_env_file("$config{'daemons_dir'}/$ac", \%daemon)) {
		# Display onboot flag from daemons file
		$boot = lc($daemon{'ONBOOT'}) eq 'yes';
		print "<tr> <td><b>$text{'edit_boot'}</b></td>\n";
		printf "<td><input name=boot type=radio value=1 %s> %s\n",
			$boot ? 'checked' : '', $text{'yes'};
		printf "<input name=boot type=radio value=0 %s> %s</td></tr>\n",
			$boot ? '' : 'checked', $text{'no'};
		}

	# Display which runlevels the action is started/stopped in
	print "</table></td></tr></table><p>\n";

	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'edit_levels'}</b></td> </tr>\n";
	print "<tr $cb> <td><b><table width=100%>\n";
	if ($ac) {
		foreach $s (&action_levels('S', $ac)) {
			@s = split(/\s+/, $s);
			$spri{$s[0]} = $s[1];
			}
		foreach $k (&action_levels('K', $ac)) {
			@k = split(/\s+/, $k);
			$kpri{$k[0]} = $k[1];
			}
		}
	@boot = &get_inittab_runlevel();
	foreach $rl (&list_runlevels()) {
		print "<tr>\n" if (!$sw);
		if (&indexof($rl, @boot) == -1) {
			print "<td><b>",&text('edit_rl', $rl),"</b></td>\n";
			}
		else {
			print "<td><b><i>",&text('edit_rl', $rl),
			      "</i></b></td>\n";
			}

		$od = $config{'order_digits'};
		printf "<td><input type=checkbox name=S$rl value=1 %s>\n",
			defined($spri{$rl}) ? "checked" : "";
		print $text{'edit_startat'},"\n";
		print "<input name=pri_S$rl size=$od value=$spri{$rl}></td>\n";

		printf "<td><input type=checkbox name=K$rl value=1 %s>\n",
			defined($kpri{$rl}) ? "checked" : "";
		print $text{'edit_stopat'},"\n";
		print "<input name=pri_K$rl size=$od value=$kpri{$rl}></td>\n";
		print "</tr>\n" if ($sw);
		$sw = !$sw;
		}
	print "<td colspan=3><br></td> </tr>\n" if ($sw);
	print "</table></td></tr></table>\n";
	}

if ($ty != 2) {
	print "<table width=100%><tr>\n";
	if ($access{'bootup'} == 1) {
		print "<td><input type=submit value=\"$text{'save'}\"></td>\n";
		}

	print "</form><form action=\"start_stop.cgi\">\n";
	print "<input type=hidden name=file value=\"$file\">\n";
	print "<input type=hidden name=name value=\"$ac\">\n";
	$args = join("+", @ARGV);
	print "<input type=hidden name=back value=\"edit_action.cgi?$args\">\n";
	print "<td align=center>\n";
	print "<input type=submit name=start value=\"$text{'edit_startnow'}\">\n";
	if ($hasarg{'restart'}) {
		print "<input type=submit name=restart value=\"$text{'edit_restartnow'}\">\n";
		}
	if ($hasarg{'condrestart'}) {
		print "<input type=submit name=condrestart value=\"$text{'edit_condrestartnow'}\">\n";
		}
	if ($hasarg{'reload'}) {
		print "<input type=submit name=reload value=\"$text{'edit_reloadnow'}\">\n";
		}
	if ($hasarg{'status'}) {
		print "<input type=submit name=status value=\"$text{'edit_statusnow'}\">\n";
		}
	print "<input type=submit name=stop value=\"$text{'edit_stopnow'}\">\n";
	print "</td>\n";

	if ($access{'bootup'} == 1) {
		print "</form><form action=\"delete_action.cgi\">\n";
		print "<input type=hidden name=type value=\"$ty\">\n";
		print "<input type=hidden name=action value=\"$ac\">\n";
		if ($ty == 1) {
			print "<input type=hidden name=runlevel value=\"$rl\">\n";
			print "<input type=hidden name=startstop value=\"$ss\">\n";
			print "<input type=hidden name=number value=\"$num\">\n";
			}
		print "<td align=right><input type=submit ",
		      "value=\"$text{'delete'}\"></td>\n";
		}
	print "</tr></form></table><p>\n";
	}
else {
	print "<input type=submit value=\"$text{'create'}\"></form><p>\n";
	}

&ui_print_footer("", $text{'index_return'});


