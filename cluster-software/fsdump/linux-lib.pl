# linux-lib.pl

local $out = &backquote_command("dump -v 2>&1", 1);
if ($out =~ /dump\s+([0-9\.]+)b(\d+)/) {
	$dump_version = "$1$2";
	}
else {
	$out = &backquote_command("dump --version 2>&1", 1);
	if ($out =~ /dump\s+([0-9\.]+)b(\d+)/) {
		$dump_version = "$1$2";
		}
	}

$supports_tar = 1;

# supported_filesystems()
# Returns a list of filesystem types on which dumping is supported
sub supported_filesystems
{
local @rv;
push(@rv, "ext2", "ext3") if (&has_command("dump"));
push(@rv, "xfs") if (&has_command("xfsdump"));
return @rv;
}

# multiple_directory_support(fs)
# Returns 1 if some filesystem dump supports multiple directories
sub multiple_directory_support
{
return $_[0] eq "tar";
}

# dump_form(&dump)
sub dump_form
{
# Display destination options
print "<tr> <td valign=top><b>",&hlink($text{'dump_dest'}, "dest"),
      "</b></td> <td colspan=3>\n";
printf "<input type=radio name=mode value=0 %s> %s\n",
	$_[0]->{'host'} ? '' : 'checked', $text{'dump_file'};
printf "<input name=file size=50 value='%s'> %s<br>\n",
	$_[0]->{'host'} ? '' : $_[0]->{'file'},
	&file_chooser_button("file");
printf "<input type=radio name=mode value=1 %s>\n",
	$_[0]->{'host'} ? 'checked' : '';
print &text('dump_host',
	    "<input name=host size=15 value='$_[0]->{'host'}'>",
	    "<input name=huser size=8 value='$_[0]->{'huser'}'>",
	    "<input name=hfile size=20 value='$_[0]->{'hfile'}'>"),
      "</td> </tr>\n";

if ($_[0]->{'fs'} ne 'xfs') {
	# Display remote target options
	print "<tr> <td><b>",&hlink($text{'dump_rsh'},"rsh"),
	      "</b></td>\n";
	print "<td colspan=3>",
	      &rsh_command_input("rsh_def", "rsh", $_[0]->{'rsh'}),
	      "</td> </tr>\n";

	# Password option for SSH
	print "<tr> <td><b>",&hlink($text{'dump_pass2'},"pass2"),
	      "</b></td>\n";
	print "<td colspan=3>",&ui_password("pass", $_[0]->{'pass'}, 20),
	      "</td> </tr>\n";
	}
}

sub dump_options_form
{
if ($_[0]->{'fs'} eq 'tar') {
	# Display gnutar options
	print "<tr> <td><b>",&hlink($text{'dump_label'},"label"),"</b></td>\n";
	printf "<td><input name=label size=15 value='%s'></td> </tr>\n",
		$_[0]->{'label'};

	print "<tr> <td><b>",&hlink($text{'dump_blocks'},"blocks"),
	      "</b></td> <td colspan=3>\n";
	printf "<input name=blocks_def type=radio value=1 %s> %s\n",
		$_[0]->{'blocks'} ? '' : 'checked', $text{'dump_auto'};
	printf "<input name=blocks_def type=radio value=0 %s>\n",
		$_[0]->{'blocks'} ? 'checked' : '';
	printf "<input name=blocks size=8 value='%s'> kB</td> </tr>\n",
		$_[0]->{'blocks'};

	print "<tr><td><b>",&hlink($text{'dump_gzip'},"gzip"),"</b></td>\n";
	print "<td>",&ui_select("gzip", int($_[0]->{'gzip'}),
				[ [ 0, $text{'no'} ],
				  [ 1, $text{'dump_gzip1'} ],
				  [ 2, $text{'dump_gzip2'} ] ]),"</td>\n";

	print "<td><b>",&hlink($text{'dump_multi'},"multi"),"</b></td>\n";
	printf "<td><input name=multi type=radio value=1 %s> %s\n",
		$_[0]->{'multi'} ? 'checked' : '', $text{'yes'};
	printf "<input name=multi type=radio value=0 %s> %s</td> </tr>\n",
		$_[0]->{'multi'} ? '' : 'checked', $text{'no'};

	print "<tr><td><b>",&hlink($text{'dump_links'},"links"),"</b></td>\n";
	printf "<td><input name=links type=radio value=1 %s> %s\n",
		$_[0]->{'links'} ? 'checked' : '', $text{'yes'};
	printf "<input name=links type=radio value=0 %s> %s</td>\n",
		$_[0]->{'links'} ? '' : 'checked', $text{'no'};

	print "<td><b>",&hlink($text{'dump_xdev'},"xdev"),"</b></td>\n";
	printf "<td><input name=xdev type=radio value=1 %s> %s\n",
		$_[0]->{'xdev'} ? 'checked' : '', $text{'yes'};
	printf "<input name=xdev type=radio value=0 %s> %s</td> </tr>\n",
		$_[0]->{'xdev'} ? '' : 'checked', $text{'no'};

	print "<tr><td><b>",&hlink($text{'dump_notape'},"notape"),"</b></td>\n";
	printf "<td><input name=notape type=radio value=0 %s> %s\n",
		!$_[0]->{'notape'} ? 'checked' : '', $text{'yes'};
	printf "<input name=notape type=radio value=1 %s> %s</td>\n",
		!$_[0]->{'notape'} ? '' : 'checked', $text{'no'};
	}
elsif ($_[0]->{'fs'} eq 'xfs') {
	# Display xfs dump options
	print "<tr> <td><b>",&hlink($text{'dump_level'},"level"),"</b></td>\n";
	print "<td><select name=level>\n";
	foreach $l (0 .. 9) {
		printf "<option value=%d %s>%d %s\n",
			$l, $_[0]->{'level'} == $l ? "selected" : "", $l,
			$text{'dump_level_'.$l};
		}
	print "</select></td>\n";

	print "<td><b>",&hlink($text{'dump_label'},"label"),"</b></td>\n";
	printf "<td><input name=label size=15 value='%s'></td> </tr>\n",
		$_[0]->{'label'};

	print "<tr> <td><b>",&hlink($text{'dump_max'},"max"),"</b></td>\n";
	printf "<td><input type=radio name=max_def value=1 %s> %s\n",
		$_[0]->{'max'} ? '' : 'checked', $text{'dump_unlimited'};
	printf "<input type=radio name=max_def value=0 %s>\n",
		$_[0]->{'max'} ? 'checked' : '';
	printf "<input name=max size=8 value='%s'> kB</td>\n", $_[0]->{'max'};

	print "<td><b>",&hlink($text{'dump_attribs'},"attribs"),"</b></td>\n";
	printf "<td><input type=radio name=noattribs value=0 %s> %s\n",
		$_[0]->{'noattribs'} ? '' : 'checked', $text{'yes'};
	printf "<input type=radio name=noattribs value=1 %s> %s</td> </tr>\n",
		$_[0]->{'noattribs'} ? 'checked' : '', $text{'no'};

	print "<tr> <td><b>",&hlink($text{'dump_over'},"over"),"</b></td>\n";
	printf "<td><input type=radio name=over value=0 %s> %s\n",
		$_[0]->{'over'} ? '' : 'checked', $text{'yes'};
	printf "<input type=radio name=over value=1 %s> %s</td>\n",
		$_[0]->{'over'} ? 'checked' : '', $text{'no'};

	print "<td><b>",&hlink($text{'dump_invent'},"invent"),"</b></td>\n";
	printf "<td><input type=radio name=noinvent value=0 %s> %s\n",
		$_[0]->{'noinvent'} ? '' : 'checked', $text{'yes'};
	printf "<input type=radio name=noinvent value=1 %s> %s</td> </tr>\n",
		$_[0]->{'noinvent'} ? 'checked' : '', $text{'no'};

	print "<tr> <td><b>",&hlink($text{'dump_overwrite'},"overwrite"),
	      "</b></td>\n";
	printf "<td><input type=radio name=overwrite value=1 %s> %s\n",
		$_[0]->{'overwrite'} ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=overwrite value=0 %s> %s</td>\n",
		$_[0]->{'overwrite'} ? '' : 'checked', $text{'no'};

	print "<td><b>",&hlink($text{'dump_erase'},"erase"),"</b></td>\n";
	printf "<td><input type=radio name=erase value=1 %s> %s\n",
		$_[0]->{'erase'} ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=erase value=0 %s> %s</td> </tr>\n",
		$_[0]->{'erase'} ? '' : 'checked', $text{'no'};

	print "<tr> <td><b>",&hlink($text{'dump_bsize'},"bsize"),
	      "</b></td> <td>\n";
	printf "<input name=bsize_def type=radio value=1 %s> %s\n",
		$_[0]->{'bsize'} ? '' : 'checked', $text{'default'};
	printf "<input name=bsize_def type=radio value=0 %s>\n",
		$_[0]->{'bsize'} ? 'checked' : '';
	printf "<input name=bsize size=8 value='%s'> kB</td>\n",
	}
else {
	# Display ext2/3 filesystem dump options
	print "<tr> <td><b>",&hlink($text{'dump_update'},"update"),
	      "</b></td>\n";
	printf "<td><input name=update type=radio value=1 %s> %s\n",
		$_[0]->{'update'} ? 'checked' : '', $text{'yes'};
	printf "<input name=update type=radio value=0 %s> %s</td>\n",
		$_[0]->{'update'} ? '' : 'checked', $text{'no'};

	print "<td><b>",&hlink($text{'dump_multi'},"multi"),"</b></td>\n";
	printf "<td><input name=multi type=radio value=1 %s> %s\n",
		$_[0]->{'multi'} ? 'checked' : '', $text{'yes'};
	printf "<input name=multi type=radio value=0 %s> %s</td> </tr>\n",
		$_[0]->{'multi'} ? '' : 'checked', $text{'no'};

	print "<tr> <td><b>",&hlink($text{'dump_level'},"level"),"</b></td>\n";
	print "<td><select name=level>\n";
	foreach $l (0 .. 9) {
		printf "<option value=%d %s>%d %s\n",
			$l, $_[0]->{'level'} == $l ? "selected" : "", $l,
			$text{'dump_level_'.$l};
		}
	print "</select></td>\n";

	print "<td><b>",&hlink($text{'dump_label'},"label"),"</b></td>\n";
	printf "<td><input name=label size=15 value='%s'></td> </tr>\n",
		$_[0]->{'label'};

	print "<tr> <td><b>",&hlink($text{'dump_blocks'},"blocks"),
	      "</b></td> <td colspan=3>\n";
	printf "<input name=blocks_def type=radio value=1 %s> %s\n",
		$_[0]->{'blocks'} ? '' : 'checked', $text{'dump_auto'};
	printf "<input name=blocks_def type=radio value=0 %s>\n",
		$_[0]->{'blocks'} ? 'checked' : '';
	printf "<input name=blocks size=8 value='%s'> kB</td>\n",
		$_[0]->{'blocks'};

	print "<tr> <td><b>",&hlink($text{'dump_bsize'},"bsize"),
	      "</b></td> <td colspan=3>\n";
	printf "<input name=bsize_def type=radio value=1 %s> %s\n",
		$_[0]->{'bsize'} ? '' : 'checked', $text{'default'};
	printf "<input name=bsize_def type=radio value=0 %s>\n",
		$_[0]->{'bsize'} ? 'checked' : '';
	printf "<input name=bsize size=8 value='%s'> kB</td>\n",
		$_[0]->{'bsize'};

	print "<tr><td><b>",&hlink($text{'dump_honour'},"honour"),"</b></td>\n";
	printf "<td><input name=honour type=radio value=1 %s> %s\n",
		$_[0]->{'honour'} ? 'checked' : '', $text{'yes'};
	printf "<input name=honour type=radio value=0 %s> %s</td>\n",
		$_[0]->{'honour'} ? '' : 'checked', $text{'no'};

	if ($dump_version >= 0.424) {
		print "<td><b>",&hlink($text{'dump_comp'},"comp"),
		      "</b></td> <td>\n";
		printf "<input name=comp_def type=radio value=1 %s> %s\n",
			$_[0]->{'comp'} ? '' : 'checked', $text{'no'};
		printf "<input name=comp_def type=radio value=0 %s> %s\n",
			$_[0]->{'comp'} ? 'checked' : '',$text{'dump_complvl'};
		printf "<input name=comp size=4 value='%s'></td>\n",
			$_[0]->{'comp'} || 2;
		print "</tr>\n";
		print "<tr>\n";
		}
	}

# Re-mount option
print "<td><b>",&hlink($text{'dump_remount'},"remount"),"</b></td>\n";
print "<td>",&ui_yesno_radio("remount", int($_[0]->{'remount'})),"</td> </tr>\n";

if ($_[0]->{'fs'} eq 'tar') {
	# rmt path option
	print "<tr><td><b>",&hlink($text{'dump_rmt'},"rmt"),"</b></td>\n";
	print "<td colspan=3>",&ui_opt_textbox("rmt", $_[0]->{'rmt'}, 30,
					$text{'default'}),"</td> </tr>\n";
	}
}

# parse_dump(&dump)
sub parse_dump
{
# Parse destination options
if ($in{'mode'} == 0) {
	$in{'file'} =~ /\S/ || &error($text{'dump_efile'});
	$_[0]->{'file'} = $in{'file'};
	delete($_[0]->{'host'});
	delete($_[0]->{'huser'});
	delete($_[0]->{'hfile'});
	}
else {
	gethostbyname($in{'host'}) || &check_ipaddress($in{'host'}) ||
		&error($text{'dump_ehost'});
	$_[0]->{'host'} = $in{'host'};
	$in{'huser'} =~ /^\S*$/ || &error($text{'dump_ehuser'});
	$_[0]->{'huser'} = $in{'huser'};
	$in{'hfile'} || &error($text{'dump_ehfile'});
	$_[0]->{'hfile'} = $in{'hfile'};
	delete($_[0]->{'file'});
	}

if ($_[0]->{'fs'} eq 'tar') {
	# Parse tar options
	$_[0]->{'rsh'} = &rsh_command_parse("rsh_def", "rsh");
	$_[0]->{'pass'} = $in{'pass'};
	$in{'label'} =~ /^\S*$/ && length($in{'label'}) < 16 ||
		&error($text{'dump_elabel'});
	$_[0]->{'label'} = $in{'label'};
	if ($in{'blocks_def'}) {
		delete($_[0]->{'blocks'});
		}
	else {
		$in{'blocks'} =~ /^\d+$/ || &error($text{'dump_eblocks'});
		$_[0]->{'blocks'} = $in{'blocks'};
		$in{'gzip'} && &error($text{'dump_egzip'});
		}
	$_[0]->{'gzip'} = $in{'gzip'};
	$_[0]->{'multi'} = $in{'multi'};
	$_[0]->{'links'} = $in{'links'};
	$_[0]->{'xdev'} = $in{'xdev'};
	if ($in{'multi'}) {
		!-c $in{'file'} && !-b $in{'file'} ||
			&error($text{'dump_emulti'});
		$in{'gzip'} && &error($text{'dump_egzip2'});
		$in{'mode'} == 0 || &error($text{'dump_emulti2'});
		}
	$_[0]->{'notape'} = $in{'notape'};
	if ($in{'rmt_def'}) {
		delete($_[0]->{'rmt'});
		}
	else {
		$in{'rmt'} =~ /^\S+$/ || &error($text{'dump_ermt'});
		$_[0]->{'rmt'} = $in{'rmt'};
		}
	}
elsif ($_[0]->{'fs'} eq 'xfs') {
	# Parse xfs options
	local $mp;
	foreach $m (&foreign_call("mount", "list_mounted")) {
		$mp++ if ($m->[0] eq $in{'dir'});
		}
	$mp || &error($text{'dump_emp'});
	$in{'label'} =~ /^\S*$/ && length($in{'label'}) < 256 ||
		&error($text{'dump_elabel2'});
	$_[0]->{'label'} = $in{'label'};
	$_[0]->{'level'} = $in{'level'};
	if ($in{'max_def'}) {
		delete($_[0]->{'max'});
		}
	else {
		$in{'max'} =~ /^\d+$/ || &error($text{'dump_emax'});
		$_[0]->{'max'} = $in{'max'};
		}
	$_[0]->{'noattribs'} = $in{'noattribs'};
	$_[0]->{'over'} = $in{'over'};
	$_[0]->{'noinvent'} = $in{'noinvent'};
	$_[0]->{'overwrite'} = $in{'overwrite'};
	$_[0]->{'erase'} = $in{'erase'};
	if ($in{'bsize_def'}) {
		delete($_[0]->{'bsize'});
		}
	else {
		$in{'bsize'} =~ /^\d+$/ || &error($text{'dump_ebsize'});
		$_[0]->{'bsize'} = $in{'bsize'};
		}
	}
else {
	# Parse ext2/3 options
	$_[0]->{'rsh'} = &rsh_command_parse("rsh_def", "rsh");
	$_[0]->{'pass'} = $in{'pass'};
	$_[0]->{'update'} = $in{'update'};
	$_[0]->{'multi'} = $in{'multi'};
	$_[0]->{'level'} = $in{'level'};
	$in{'label'} =~ /^\S*$/ && length($in{'label'}) < 16 ||
		&error($text{'dump_elabel'});
	$_[0]->{'label'} = $in{'label'};
	if ($in{'blocks_def'}) {
		delete($_[0]->{'blocks'});
		}
	else {
		$in{'blocks'} =~ /^\d+$/ || &error($text{'dump_eblocks'});
		$_[0]->{'blocks'} = $in{'blocks'};
		}
	if ($in{'bsize_def'}) {
		delete($_[0]->{'bsize'});
		}
	else {
		$in{'bsize'} =~ /^\d+$/ || &error($text{'dump_ebsize'});
		$_[0]->{'bsize'} = $in{'bsize'};
		}
	$_[0]->{'honour'} = $in{'honour'};
	if ($in{'comp_def'} || !defined($in{'comp'})) {
		delete($_[0]->{'comp'});
		}
	else {
		$in{'comp'} =~ /^[1-9]\d*$/ || &error($text{'dump_ecomp'});
		$_[0]->{'comp'} = $in{'comp'};
		}
	}
$_[0]->{'remount'} = $in{'remount'};
}

# execute_dump(&dump, filehandle, escape, background-mode)
# Executes a dump and displays the output
sub execute_dump
{
local $fh = $_[1];
local ($cmd);
($flag, $hfile) = &dump_flag($_[0]);
local $tapecmd = $_[0]->{'multi'} && $_[0]->{'fs'} eq 'tar' ? $multi_cmd :
		 $_[0]->{'notape'} ? undef :
		 $_[0]->{'multi'} ? undef :
		 $_[3] && !$config{'nonewtape'} ? $newtape_cmd : $notape_cmd;
local @dirs = split(/\s+/, $_[0]->{'dir'});
if ($_[0]->{'fs'} eq 'tar') {
	# tar format backup
	$cmd = "tar -c $flag";
	$cmd .= " -V '$_[0]->{'label'}'" if ($_[0]->{'label'});
	$cmd .= " -L $_[0]->{'blocks'}" if ($_[0]->{'blocks'});
	$cmd .= " -z" if ($_[0]->{'gzip'} == 1);
	$cmd .= " --bzip" if ($_[0]->{'gzip'} == 2);
	$cmd .= " -M" if ($_[0]->{'multi'});
	$cmd .= " -h" if ($_[0]->{'links'});
	$cmd .= " -l" if ($_[0]->{'xdev'});
	$cmd .= " -F \"$tapecmd $_[0]->{'id'}\"" if (!$_[0]->{'gzip'} && $tapecmd);
	$cmd .= " --rsh-command=".quotemeta($_[0]->{'rsh'}) if ($_[0]->{'rsh'});
	$cmd .= " --rmt-command=".quotemeta($_[0]->{'rmt'}) if ($_[0]->{'rmt'});
	$cmd .= " $_[0]->{'extra'}" if ($_[0]->{'extra'});
	$cmd .= " ".join(" ", map { "'$_'" } @dirs);
	}
elsif ($_[0]->{'fs'} eq 'xfs') {
	# xfs backup
	$cmd = "xfsdump -l $_[0]->{'level'}";
	$cmd .= $flag;
	$cmd .= " -L '$_[0]->{'label'}'" if ($_[0]->{'label'});
	$cmd .= " -M '$_[0]->{'label'}'" if ($_[0]->{'label'});
	$cmd .= " -z '$_[0]->{'max'}'" if ($_[0]->{'max'});
	$cmd .= " -A" if ($_[0]->{'noattribs'});
	$cmd .= " -F" if ($_[0]->{'over'});
	$cmd .= " -J" if ($_[0]->{'noinvent'});
	$cmd .= " -o" if ($_[0]->{'overwrite'});
	$cmd .= " -E -F" if ($_[0]->{'erase'});
	$cmd .= " -b $_[0]->{'bsize'}" if ($_[0]->{'bsize'});
	$cmd .= " $_[0]->{'extra'}" if ($_[0]->{'extra'});
	$cmd .= " ".join(" ", map { "'$_'" } @dirs);
	}
else {
	# ext2/3 backup
	$cmd = "dump -$_[0]->{'level'}";
	$cmd .= $flag;
	$cmd .= " -u" if ($_[0]->{'update'});
	$cmd .= " -M" if ($_[0]->{'multi'});
	$cmd .= " -L '$_[0]->{'label'}'" if ($_[0]->{'label'});
	$cmd .= " -B $_[0]->{'blocks'}" if ($_[0]->{'blocks'});
	$cmd .= " -b $_[0]->{'bsize'}" if ($_[0]->{'bsize'});
	$cmd .= " -h0" if ($_[0]->{'honour'});
	$cmd .= " -j$_[0]->{'comp'}" if ($_[0]->{'comp'});
	$cmd .= " -F \"$tapecmd $_[0]->{'id'}\"" if ($tapecmd);
	$cmd .= " $_[0]->{'extra'}" if ($_[0]->{'extra'});
	$cmd .= " '$_[0]->{'dir'}'";
	if ($_[0]->{'rsh'}) {
		$cmd = "RSH=\"$_[0]->{'rsh'}\" RMT=\"touch '$hfile'; /etc/rmt\" $cmd";
		}
	else {
		$cmd = "RMT=\"touch '$hfile'; /etc/rmt\" $cmd";
		}
	}

&system_logged("sync");
sleep(1);

# Remount with noatime, if needed
if ($_[0]->{'remount'}) {
	local @fs = &directory_filesystem($dirs[0]);
	&mount::parse_options($fs[2], $fs[3]);
	$mount::options{'noatime'} = '';
	$fs[3] = &mount::join_options($fs[2]);
	local $err = &mount::remount_dir(@fs);
	if ($err) {
		$err =~ s/<[^>]*>//g;
		print $fh "Failed to re-mount with noatime option : $err\n";
		return 0;
		}
	}

# Run the command, which may call SSH to do a remote login
$ENV{'DUMP_PASSWORD'} = $_[0]->{'pass'};
local $got = &run_ssh_command($cmd, $fh, $_[2], $_[0]->{'pass'});
if ($_[0]->{'multi'} && $_[0]->{'fs'} eq 'tar') {
	# Run multi-file switch command one last time
	&execute_command("$multi_cmd $_[0]->{'id'} >/dev/null 2>&1");
	}

# Remount with atime option
if ($_[0]->{'remount'}) {
	local @fs = &directory_filesystem($dirs[0]);
	&mount::parse_options($fs[2], $fs[3]);
	delete($mount::options{'noatime'});
	$mount::options{'atime'} = '';
	$fs[3] = &mount::join_options($fs[2]);
	local $err = &mount::remount_dir(@fs);
	}

return $got ? 0 : 1;
}

# dump_flag(&dump)
# Given a dump, returns the -f flag and server-side file
sub dump_flag
{
local ($flag, $hfile);
if ($_[0]->{'huser'}) {
	$hfile = &date_subs($_[0]->{'hfile'});
	$flag = " -f '$_[0]->{'huser'}\@$_[0]->{'host'}:$hfile'";
	}
elsif ($_[0]->{'host'}) {
	$hfile = &date_subs($_[0]->{'hfile'});
	$flag = " -f '$_[0]->{'host'}:$hfile'";
	}
else {
	$flag = " -f '".&date_subs($_[0]->{'file'})."'";
	}
return ($flag, $hfile);
}

# verify_dump(&dump, filehandle, escape, background-mode)
# Verifies a dump, returning 1 if OK and 0 if not
sub verify_dump
{
# Build verify command
local $fh = $_[1];
local $vcmd;
local ($flag, $hfile) = &dump_flag($_[0]);
if ($_[0]->{'fs'} eq "tar") {
	$vcmd = "tar -t -v";
	$vcmd .= " -z" if ($_[0]->{'gzip'} == 1);
	$vcmd .= " --bzip" if ($_[0]->{'gzip'} == 2);
	}
elsif ($_[0]->{'fs'} eq "xfs") {
	$vcmd = "xfsrestore -t";
	}
else {
	$vcmd = "restore -t";
	}
$vcmd .= $flag;
if ($_[0]->{'fs'} eq "tar") {
	$vcmd .= " --rsh-command=$_[0]->{'rsh'}" if ($_[0]->{'rsh'});
	}
elsif ($_[0]->{'fs'} ne "xfs") {
	if ($_[0]->{'rsh'}) {
		$vcmd = "RSH=\"$_[0]->{'rsh'}\" RMT=\"touch '$hfile'; /etc/rmt\" $vcmd";
		}
	else {
		$vcmd = "RMT=\"touch '$hfile'; /etc/rmt\" $vcmd";
		}
	}

# Run it
$vcmd .= " >/dev/null";
local $vgot = &run_ssh_command($vcmd, $fh, $_[2], $_[0]->{'pass'});
return $vgot ? 0 : 1;
}

# dump_dest(&dump)
sub dump_dest
{
if ($_[0]->{'file'}) {
	return "<tt>".&html_escape($_[0]->{'file'})."</tt>";
	}
elsif ($_[0]->{'huser'}) {
	return "<tt>".&html_escape("$_[0]->{'huser'}\@$_[0]->{'host'}:$_[0]->{'hfile'}")."</tt>";
	}
else {
	return "<tt>".&html_escape("$_[0]->{'host'}:$_[0]->{'hfile'}")."</tt>";
	}
}

# missing_restore_command(filesystem)
sub missing_restore_command
{
local $cmd = $_[0] eq 'xfs' ? 'xfsrestore' : 'restore';
return &has_command($cmd) ? undef : $cmd;
}

# restore_form(filesystem, [&dump])
sub restore_form
{
# common options
print "<tr> <td valign=top><b>",&hlink($text{'restore_src'}, "rsrc"),
      "</b></td>\n";
printf "<td colspan=3><input type=radio name=mode value=0 %s> %s\n",
	$_[1]->{'host'} ? "" : "checked", $text{'dump_file'};
printf "<input name=file size=50 value='%s'> %s<br>\n",
	$_[1]->{'host'} ? "" : $_[1]->{'file'}, &file_chooser_button("file");
printf "<input type=radio name=mode value=1 %s>\n",
	$_[1]->{'host'} ? "checked" : "";
print &text('dump_host',
	    "<input name=host size=15 value='$_[1]->{'host'}'>",
	    "<input name=huser size=8 value='$_[1]->{'huser'}'>",
	    "<input name=hfile size=20 value='$_[1]->{'hfile'}'>"),
      "</td> </tr>\n";

if ($_[0] eq 'tar') {
	# tar restore options
	print "<tr> <td><b>",&hlink($text{'restore_rsh'},"rrsh"),
	      "</b></td>\n";
	print "<td colspan=3>",
	      &rsh_command_input("rsh_def", "rsh", $_[1]->{'rsh'}),
	      "</td> </tr>\n";

	# Password option for SSH
	print "<tr> <td><b>",&hlink($text{'dump_pass2'},"passs"),
	      "</b></td>\n";
	print "<td colspan=3>",&ui_password("pass", $_[0]->{'pass'}, 20),
	      "</td> </tr>\n";

	print "<tr> <td><b>",&hlink($text{'restore_files'},"rfiles"),
	      "</b></td>\n";
	print "<td colspan=3><input type=radio name=files_def value=1 checked> ",
	      "$text{'restore_all'}\n";
	print "<input type=radio name=files_def value=0> $text{'restore_sel'}\n";
	print "<input name=files size=40></td> </tr>\n";

	print "<tr> <td><b>",&hlink($text{'restore_dir'},"rdir"),
	      "</b></td> <td colspan=3>\n";
	print "<input name=dir size=50> ",&file_chooser_button("dir", 1),
	      "</td> </tr>\n";

	print "<tr> <td><b>",&hlink($text{'restore_perms'},"perms"),"</td>\n";
	print "<td><input type=radio name=perms value=1> $text{'yes'}\n";
	print "<input type=radio name=perms value=0 checked> $text{'no'}</td>\n";

	print "<td><b>",&hlink($text{'restore_gzip'},"rgzip"),"</td>\n";
	print "<td>",&ui_select("gzip", $_[1]->{'gzip'},
				[ [ 0, $text{'no'} ],
				  [ 1, $text{'dump_gzip1'} ],
				  [ 2, $text{'dump_gzip2'} ] ]),"</td> </tr>\n";

	print "<tr> <td><b>",&hlink($text{'restore_keep'},"keep"),"</td>\n";
	print "<td><input type=radio name=keep value=1> $text{'yes'}\n";
	print "<input type=radio name=keep value=0 checked> $text{'no'}</td>\n";

	print "<td><b>",&hlink($text{'restore_multi'},"rmulti"),
	      "</b></td>\n";
	print "<td><input type=radio name=multi value=1> $text{'yes'}\n";
	print "<input type=radio name=multi value=0 checked> $text{'no'}</td> </tr>\n";

	print "<tr> <td><b>",&hlink($text{'restore_test'},"rtest"),"</td>\n";
	print "<td><input type=radio name=test value=1> $text{'yes'}\n";
	print "<input type=radio name=test value=0 checked> $text{'no'}</td> </tr>\n";

	print "</tr>\n";
	}
elsif ($_[0] eq 'xfs') {
	# xfs restore options
	print "<tr> <td><b>",&hlink($text{'restore_dir'},"rdir"),
	      "</b></td> <td colspan=3>\n";
	print "<input name=dir size=50> ",&file_chooser_button("dir", 1),
	      "</td> </tr>\n";

	print "<tr> <td><b>",&hlink($text{'restore_over'},"rover"),
	      "</b></td>\n";
	print "<td colspan=3><input type=radio name=over value=0 checked> ",
	      "$text{'restore_over0'}\n";
	print "<input type=radio name=over value=1> $text{'restore_over1'}\n";
	print "<input type=radio name=over value=2> ",
	      "$text{'restore_over2'}</td> </tr>\n";

	print "<tr> <td><b>",&hlink($text{'restore_noattribs'},"rnoattribs"),
	      "</b></td> <td>\n";
	print "<input type=radio name=noattribs value=0 checked> $text{'yes'}\n";
	print "<input type=radio name=noattribs value=1> $text{'no'}</td>\n";

	print "<td><b>",&hlink($text{'restore_label'},"rlabel"),"</b></td>\n";
	print "<td><input name=label size=20></td> </tr>\n";

	print "<tr> <td><b>",&hlink($text{'restore_test'},"rtest"),"</td>\n";
	print "<td><input type=radio name=test value=1> $text{'yes'}\n";
	print "<input type=radio name=test value=0 checked> $text{'no'}</td> </tr>\n";
	}
else {
	# ext2/3 restore options
	print "<tr> <td><b>",&hlink($text{'restore_rsh'},"rrsh"),
	      "</b></td>\n";
	print "<td colspan=3>",
	      &rsh_command_input("rsh_def", "rsh", $_[1]->{'rsh'}),
	      "</td> </tr>\n";

	# Password option for SSH
	print "<tr> <td><b>",&hlink($text{'dump_pass2'},"pass2"),
	      "</b></td>\n";
	print "<td colspan=3>",&ui_password("pass", $_[0]->{'pass'}, 20),
	      "</td> </tr>\n";

	print "<tr> <td><b>",&hlink($text{'restore_files'},"rfiles"),
	      "</b></td>\n";
	print "<td colspan=3><input type=radio name=files_def value=1 checked> ",
	      "$text{'restore_all'}\n";
	print "<input type=radio name=files_def value=0> $text{'restore_sel'}\n";
	print "<input name=files size=40></td> </tr>\n";

	print "<tr> <td><b>",&hlink($text{'restore_dir'},"rdir"),"</td>\n";
	print "<td colspan=3><input name=dir size=40> ",
		&file_chooser_button("dir", 1),"</td> </tr>\n";

	print "<tr> <td><b>",&hlink($text{'restore_multi'},"rmulti"),
	      "</b></td>\n";
	print "<td><input type=radio name=multi value=1> $text{'yes'}\n";
	print "<input type=radio name=multi value=0 checked> $text{'no'}</td>\n";

	print "<td><b>",&hlink($text{'restore_test'},"rtest"),"</td>\n";
	print "<td><input type=radio name=test value=1> $text{'yes'}\n";
	print "<input type=radio name=test value=0 checked> $text{'no'}</td> </tr>\n";
	}
}

# parse_restore(filesystem)
# Parses inputs from restore_form() and returns a command to be passed to
# restore_backup()
sub parse_restore
{
local $cmd;
if ($_[0] eq 'tar') {
	$cmd = "tar";
	if ($in{'test'}) {
		$cmd .= " -t -v";
		}
	else {
		$cmd .= " -x";
		}
	}
elsif ($_[0] eq 'xfs') {
	$cmd = "xfsrestore";
	$cmd .= " -t" if ($in{'test'});
	}
else {
	$cmd = "restore";
	$cmd .= ($in{'test'} ? " -t" : " -x");
	}
if ($in{'mode'} == 0) {
	$in{'file'} || &error($text{'restore_efile'});
	$cmd .= " -f '$in{'file'}'";
	}
else {
	gethostbyname($in{'host'}) || &check_ipaddress($in{'host'}) ||
		&error($text{'restore_ehost'});
	$in{'huser'} =~ /^\S*$/ || &error($text{'restore_ehuser'});
	$in{'hfile'} || &error($text{'restore_ehfile'});
	if ($in{'huser'}) {
		$cmd .= " -f '$in{'huser'}\@$in{'host'}:$in{'hfile'}'";
		}
	else {
		$cmd .= " -f '$in{'host'}:$in{'hfile'}'";
		}
	}
if ($_[0] eq 'tar') {
	# parse tar options
	$cmd .= " -p" if ($in{'perms'});
	$cmd .= " -z" if ($in{'gzip'} == 1);
	$cmd .= " --bzip" if ($in{'gzip'} == 2);
	$cmd .= " -k" if ($in{'keep'});
	if ($in{'multi'}) {
		!-c $in{'file'} && !-b $in{'file'} ||
			&error($text{'restore_emulti'});
		$in{'mode'} == 0 || &error($text{'restore_emulti2'});
		$cmd .= " -M -F \"$rmulti_cmd $in{'file'}\"";
		}
	local $rsh = &rsh_command_parse("rsh_def", "rsh");
	if ($rsh) {
		$cmd .= " --rsh-command=".quotemeta($rsh);
		}
	$cmd .= " $in{'extra'}" if ($in{'extra'});
	if (!$in{'files_def'}) {
		$in{'files'} || &error($text{'restore_efiles'});
		$cmd .= " $in{'files'}";
		}
	-d $in{'dir'} || &error($text{'restore_edir'});
	$cmd = "cd '$in{'dir'}' && $cmd";
	if ($in{'multi'}) {
		$cmd = "$rmulti_cmd $in{'file'} 1 && $cmd";
		}
	}
elsif ($_[0] eq 'xfs') {
	# parse xfs options
	$cmd .= " -E" if ($in{'over'} == 1);
	$cmd .= " -e" if ($in{'over'} == 2);
	$cmd .= " -A" if ($in{'noattribs'});
	$cmd .= " -L '$in{'label'}'" if ($in{'label'});
	$cmd .= " -F";
	$cmd .= " $in{'extra'}" if ($in{'extra'});
	if (!$in{'test'}) {
		-d $in{'dir'} || &error($text{'restore_edir'});
		$cmd .= " '$in{'dir'}'";
		}
	}
else {
	# parse ext2/3 options
	local $rsh = &rsh_command_parse("rsh_def", "rsh");
	if ($rsh) {
		$cmd = "RSH=\"$rsh\" $cmd";
		}

	if ($in{'multi'}) {
		$cmd .= " -M";
		if ($dump_version >= 0.428 && $in{'extra'} !~ /-a/) {
			$cmd .= " -a";
			}
		}
	$cmd .= " -u";		# force overwrite
	$cmd .= " $in{'extra'}" if ($in{'extra'});
	if (!$in{'files_def'}) {
		$in{'files'} || &error($text{'restore_efiles'});
		$cmd .= " $in{'files'}";
		}
	-d $in{'dir'} || &error($text{'restore_edir'});
	}
return $cmd;
}

# restore_backup(filesystem, command)
# Restores a backup based on inputs from restore_form(), and displays the results
sub restore_backup
{
&additional_log('exec', undef, $_[1]);
$ENV{'DUMP_PASSWORD'} = $in{'pass'};
if ($_[0] eq 'xfs') {
	# Just run the xfsrestore command
	&open_execute_command(CMD, "$_[1] 2>&1 </dev/null", 1);
	while(<CMD>) {
		print &html_escape($_);
		}
	close(CMD);
	return $? || undef;
	}
else {
	# Need to supply prompts
	&foreign_require("proc", "proc-lib.pl");
	local ($fh, $fpid) = &foreign_call("proc", "pty_process_exec", "cd '$in{'dir'}' ; $_[1]");
	local $donevolume;
	while(1) {
		local $rv = &wait_for($fh, "(.*next volume #)", "(.*set owner.mode for.*\\[yn\\])", "((.*)\\[yn\\])", "(.*enter volume name)", "password:", "yes\\/no", "(.*\\n)");
		last if ($rv < 0);
		print &html_escape($matches[1]);
		if ($rv == 0) {
			if ($donevolume++) {
				return $text{'restore_evolume'};
				}
			else {
				syswrite($fh, "1\n", 2);
				}
			}
		elsif ($rv == 1) {
			syswrite($fh, "n\n", 2);
			}
		elsif ($rv == 3) {
			syswrite($fh, "\n", 1);
			}
		elsif ($rv == 2) {
			return &text('restore_equestion',
				     "<tt>$matches[2]</tt>");
			}
		elsif ($rv == 4) {
			syswrite($fh, "$in{'pass'}\n");
			}
		elsif ($rv == 5) {
			syswrite($fh, "yes\n");
			}
		}
	close($fh);
	waitpid($fpid, 0);
	return $? || undef;
	}
}

1;

