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
push(@rv, "ext2", "ext3", "ext4") if (&has_command("dump"));
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
print &ui_table_row(&hlink($text{'dump_dest'}, "dest"),
   &ui_radio("mode", $_[0]->{'host'} ? 1 : 0,
	[ [ 0, $text{'dump_file'}." ".
	       &ui_textbox("file", $_[0]->{'file'}, 50).
	       " ".&file_chooser_button("file")."<br>" ],
	  [ 1, &text('dump_host',
		     &ui_textbox("host", $_[0]->{'host'}, 20),
		     &ui_textbox("huser", $_[0]->{'huser'}, 15),
		     &ui_textbox("hfile", $_[0]->{'hfile'}, 40)) ] ]), 3);

if ($_[0]->{'fs'} ne 'xfs') {
	# Display remote target options
	print &ui_table_row(&hlink($text{'dump_rsh'},"rsh"),
		      &rsh_command_input("rsh_def", "rsh", $_[0]->{'rsh'}), 3);

	# Password option for SSH
	print &ui_table_row(&hlink($text{'dump_pass2'},"pass2"),
		      &ui_password("pass", $_[0]->{'pass'}, 20), 3);
	}
}

sub dump_options_form
{
local ($dump, $tds) = @_;
if ($_[0]->{'fs'} eq 'tar') {
	# Display gnutar options
	print &ui_table_row(&hlink($text{'dump_label'},"label"),
			    &ui_textbox("label", $_[0]->{'label'}, 15),
			    1, $tds);

	print &ui_table_row(&hlink($text{'dump_blocks'},"blocks"),
			    &ui_opt_textbox("blocks", $_[0]->{'blocks'}, 8,
					    $text{'dump_auto'})." kB",
			    3, $tds);

	print &ui_table_row(&hlink($text{'dump_exclude'}, "exclude"),
			    &ui_textbox("exclude", $_[0]->{'exclude'}, 50),
			    3, $tds);

	print &ui_table_row(&hlink($text{'dump_gzip'},"gzip"),
			    &ui_select("gzip", int($_[0]->{'gzip'}),
				[ [ 0, $text{'no'} ],
				  [ 1, $text{'dump_gzip1'} ],
				  [ 2, $text{'dump_gzip2'} ],
				  [ 3, $text{'dump_gzip3'} ] ]), 1, $tds);

	print &ui_table_row(&hlink($text{'dump_multi'},"multi"),
			    &ui_yesno_radio("multi", int($_[0]->{'multi'})),
			    1, $tds);

	print &ui_table_row(&hlink($text{'dump_links'},"links"),
			    &ui_yesno_radio("links", int($_[0]->{'links'})),
			    1, $tds);

	print &ui_table_row(&hlink($text{'dump_xdev'},"xdev"),
			    &ui_yesno_radio("xdev", int($_[0]->{'xdev'})),
			    1, $tds);

	print &ui_table_row(&hlink($text{'dump_notape'},"notape"),
			    &ui_radio("notape", int($_[0]->{'notape'}),
				  [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]),
			    1, $tds);

	print &ui_table_row(&hlink($text{'dump_update2'},"tarupdate"),
			    &ui_yesno_radio("update", int($_[0]->{'update'})),
			    1, $tds);

	print &ui_table_row(&hlink($text{'dump_ignoreread'},"ignoreread"),
			    &ui_yesno_radio("ignoreread",
					    int($_[0]->{'ignoreread'})),
			    1, $tds);
	}
elsif ($_[0]->{'fs'} eq 'xfs') {
	# Display xfs dump options
	print &ui_table_row(&hlink($text{'dump_level'},"level"),
			    &ui_select("level", int($_[0]->{'level'}),
				[ map { [ $_, $text{'dump_level_'.$_} ] }
				      (0 .. 9) ]), 1, $tds);

	print &ui_table_row(&hlink($text{'dump_label'},"label"),
			    &ui_textbox("label", $_[0]->{'label'}, 15),
			    1, $tds);

	print &ui_table_row(&hlink($text{'dump_max'},"max"),
	    &ui_opt_textbox("max", $_[0]->{'max'}, 8,
			    $text{'dump_unlimited'})." kB", 1, $tds);

	print &ui_table_row(&hlink($text{'dump_attribs'},"attribs"),
			    &ui_yesno_radio("attribs", int($_[0]->{'attribs'})),
			    1, $tds);

	print &ui_table_row(&hlink($text{'dump_over'},"over"),
			    &ui_yesno_radio("over", int($_[0]->{'over'})),
			    1, $tds);

	print &ui_table_row(&hlink($text{'dump_invent'},"invent"),
			    &ui_radio("noinvent", int($_[0]->{'noinvent'}),
			      [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]),
			    1, $tds);

	print &ui_table_row(&hlink($text{'dump_overwrite'},"overwrite"),
		    &ui_yesno_radio("overwrite", int($_[0]->{'overwrite'})),
		    1, $tds);

	print &ui_table_row(&hlink($text{'dump_erase'},"erase"),
			    &ui_yesno_radio("erase", int($_[0]->{'erase'})),
			    1, $tds);

	print &ui_table_row(&hlink($text{'dump_bsize'},"bsize"),
	    &ui_opt_textbox("bsize", $_[0]->{'bsize'}, 8,
			    $text{'default'})." kB", 1, $tds);
	}
else {
	# Display ext2/3 filesystem dump options
	print &ui_table_row(&hlink($text{'dump_update'},"update"),
			    &ui_yesno_radio("update", int($_[0]->{'update'})),
			    1, $tds);

	print &ui_table_row(&hlink($text{'dump_multi'},"multi"),
			    &ui_yesno_radio("multi", int($_[0]->{'multi'})),
			    1, $tds);

	print &ui_table_row(&hlink($text{'dump_level'},"level"),
			    &ui_select("level", int($_[0]->{'level'}),
				[ map { [ $_, $text{'dump_level_'.$_} ] }
				      (0 .. 9) ]), 1, $tds);

	print &ui_table_row(&hlink($text{'dump_label'},"label"),
			    &ui_textbox("label", $_[0]->{'label'}, 15),
			    1, $tds);

	print &ui_table_row(&hlink($text{'dump_blocks'},"blocks"),
			    &ui_opt_textbox("blocks", $_[0]->{'blocks'}, 8,
					    $text{'dump_auto'})." kB",
			    3, $tds);

	print &ui_table_row(&hlink($text{'dump_bsize'},"bsize"),
	    &ui_opt_textbox("bsize", $_[0]->{'bsize'}, 8,
			    $text{'default'})." kB", 1, $tds);

	print &ui_table_row(&hlink($text{'dump_honour'},"honour"),
			    &ui_yesno_radio("honour", int($_[0]->{'honour'})),
			    1, $tds);

	if ($dump_version >= 0.424) {
		print &ui_table_row(&hlink($text{'dump_comp'},"comp"),
			&ui_opt_textbox("comp", $_[0]->{'comp'}, 4,
					$text{'no'}, $text{'dump_complvl'}),
			3, $tds);
		}
	}

# Re-mount option
print &ui_table_row(&hlink($text{'dump_remount'},"remount"),
	&ui_yesno_radio("remount", int($_[0]->{'remount'})), 1, $tds);

if ($_[0]->{'fs'} eq 'tar') {
	# rmt path option
	print &ui_table_row(&hlink($text{'dump_rmt'},"rmt"),
		&ui_opt_textbox("rmt", $_[0]->{'rmt'}, 30, $text{'default'}),
		3, $tds);
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
	&to_ipaddress($in{'host'}) ||
	    &to_ip6address($in{'host'}) ||
		&error($text{'dump_ehost'});
	$_[0]->{'host'} = $in{'host'};
	$in{'huser'} =~ /^\S*$/ || &error($text{'dump_ehuser'});
	$in{'huser'} =~ /\@/ && &error($text{'dump_ehuser2'});
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
	$_[0]->{'exclude'} = $in{'exclude'};
	$_[0]->{'gzip'} = $in{'gzip'};
	$_[0]->{'multi'} = $in{'multi'};
	$_[0]->{'links'} = $in{'links'};
	$_[0]->{'xdev'} = $in{'xdev'};
	if ($in{'update'} && $in{'rsh_def'} == 3) {
		# Cannot append via FTP
		&error($text{'dump_eftpupdate'});
		}
	$_[0]->{'update'} = $in{'update'};
	$_[0]->{'ignoreread'} = $in{'ignoreread'};
	if ($in{'gzip'} && $in{'update'}) {
		&error($text{'dump_egzip3'});
		}
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
	&is_mount_point($in{'dir'}) || &error($text{'dump_emp'});
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
	# Parse ext2/3 dump options
	$_[0]->{'rsh'} = &rsh_command_parse("rsh_def", "rsh");
	$_[0]->{'pass'} = $in{'pass'};
	if ($in{'update'}) {
		&is_mount_point($in{'dir'}) || &error($text{'dump_eupdatedir'});
		}
	$_[0]->{'update'} = $in{'update'};
	$_[0]->{'multi'} = $in{'multi'};
	if ($in{'level'} > 0) {
		&is_mount_point($in{'dir'}) || &error($text{'dump_eleveldir'});
		}
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

# execute_dump(&dump, filehandle, escape, background-mode, [time])
# Executes a dump and displays the output
sub execute_dump
{
local $fh = $_[1];
local ($cmd);
local ($flag, $hfile) = &dump_flag($_[0], $_[4]);
local $tapecmd = $_[0]->{'multi'} && $_[0]->{'fs'} eq 'tar' ? $multi_cmd :
		 $_[0]->{'notape'} ? undef :
		 $_[0]->{'multi'} ? undef :
		 $_[3] && !$config{'nonewtape'} ? $newtape_cmd : $notape_cmd;
local @dirs = $_[0]->{'tabs'} ? split(/\t+/, $_[0]->{'dir'})
			      : split(/\s+/, $_[0]->{'dir'});
@dirs = map { &date_subs($_) } @dirs;
if ($_[0]->{'fs'} eq 'tar') {
	# tar format backup
	$cmd = "tar ".($_[0]->{'update'} ? "-u" : "-c")." ".$flag;
	$cmd .= " -V '$_[0]->{'label'}'" if ($_[0]->{'label'});
	$cmd .= " -L $_[0]->{'blocks'}" if ($_[0]->{'blocks'});
	$cmd .= " -z" if ($_[0]->{'gzip'} == 1);
	$cmd .= " --bzip" if ($_[0]->{'gzip'} == 2);
	$cmd .= " -J" if ($_[0]->{'gzip'} == 3);
	$cmd .= " -M" if ($_[0]->{'multi'});
	$cmd .= " -h" if ($_[0]->{'links'});
	$cmd .= " --one-file-system" if ($_[0]->{'xdev'});
	$cmd .= " -F \"$tapecmd $_[0]->{'id'}\""
		if (!$_[0]->{'gzip'} && $tapecmd);
	$cmd .= " --rsh-command=".quotemeta($_[0]->{'rsh'})
		if ($_[0]->{'rsh'} && $_[0]->{'host'});
	$cmd .= " --rmt-command=".quotemeta($_[0]->{'rmt'})
		if ($_[0]->{'rmt'});
	$cmd .= " --ignore-failed-read" if ($_[0]->{'ignoreread'});
	if ($_[0]->{'exclude'}) {
		foreach my $e (&split_quoted_string($_[0]->{'exclude'})) {
			$cmd .= " --exclude ".quotemeta($e);
			}
		}
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

# dump_flag(&dump, at-time)
# Given a dump, returns the -f flag and server-side file
sub dump_flag
{
local ($flag, $hfile);
if ($_[0]->{'huser'}) {
	$hfile = &date_subs($_[0]->{'hfile'}, $_[1]);
	$flag = " -f '$_[0]->{'huser'}\@$_[0]->{'host'}:$hfile'";
	}
elsif ($_[0]->{'host'}) {
	$hfile = &date_subs($_[0]->{'hfile'}, $_[1]);
	$flag = " -f '$_[0]->{'host'}:$hfile'";
	}
else {
	$flag = " -f '".&date_subs($_[0]->{'file'}, $_[1])."'";
	}
return ($flag, $hfile);
}

# verify_dump(&dump, filehandle, escape, background-mode, [time])
# Verifies a dump, returning 1 if OK and 0 if not
sub verify_dump
{
# Build verify command
local $fh = $_[1];
local $vcmd;
local ($flag, $hfile) = &dump_flag($_[0], $_[4]);
if ($_[0]->{'fs'} eq "tar") {
	$vcmd = "tar -t -v";
	$vcmd .= " -z" if ($_[0]->{'gzip'} == 1);
	$vcmd .= " --bzip" if ($_[0]->{'gzip'} == 2);
	$vcmd .= " -J" if ($_[0]->{'gzip'} == 3);
	$vcmd .= " -M" if ($_[0]->{'multi'});
	}
elsif ($_[0]->{'fs'} eq "xfs") {
	$vcmd = "xfsrestore -t";
	}
else {
	$vcmd = "restore -t";
	$vcmd .= " -M" if ($_[0]->{'multi'});
	}
$vcmd .= $flag;
if ($_[0]->{'fs'} eq "tar") {
	$vcmd .= " --rsh-command=$_[0]->{'rsh'}"
		if ($_[0]->{'rsh'} && $_[0]->{'host'});
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

# restore_form(filesystem, [&dump], &tds)
sub restore_form
{
local ($fs, $dump, $tds) = @_;

# Restore from
print &ui_table_row(&hlink($text{'restore_src'}, "rsrc"),
   &ui_radio("mode", $_[1]->{'host'} ? 1 : 0,
	[ [ 0, $text{'dump_file'}." ".
	       &ui_textbox("file", $_[1]->{'file'}, 50).
	       " ".&file_chooser_button("file")."<br>" ],
	  [ 1, &text('dump_host',
		     &ui_textbox("host", $_[1]->{'host'}, 20),
		     &ui_textbox("huser", $_[1]->{'huser'}, 15),
		     &ui_textbox("hfile", $_[1]->{'hfile'}, 40)) ] ]), 3, $tds);

if ($_[0] eq 'tar') {
	# tar restore options
	print &ui_table_row(&hlink($text{'restore_rsh'},"rrsh"),
		      &rsh_command_input("rsh_def", "rsh", $_[1]->{'rsh'}),
		      3, $tds);

	# Password option for SSH
	print &ui_table_row(&hlink($text{'dump_pass2'},"passs"),
		      &ui_password("pass", $_[1]->{'pass'}, 20),
		      3, $tds);

	# Files to restore
	print &ui_table_row(&hlink($text{'restore_files'},"rfiles"),
		      &ui_opt_textbox("files", undef, 40, $text{'restore_all'},
				      $text{'restore_sel'}), 3, $tds);

	# Target dir
	print &ui_table_row(&hlink($text{'restore_dir'},"rdir"),
		      &ui_textbox("dir", undef, 50)." ".
		      &file_chooser_button("dir", 1), 3, $tds);

	# Restore permissions?
	print &ui_table_row(&hlink($text{'restore_perms'},"perms"),
		      &ui_yesno_radio("perms", 1), 1, $tds);

	# Uncompress?
	print &ui_table_row(&hlink($text{'restore_gzip'},"rgzip"),
		      &ui_select("gzip", $_[1]->{'gzip'},
				[ [ 0, $text{'no'} ],
				  [ 1, $text{'dump_gzip1'} ],
				  [ 2, $text{'dump_gzip2'} ],
				  [ 3, $text{'dump_gzip3'} ] ]), 1, $tds);

	print &ui_table_row(&hlink($text{'restore_keep'},"keep"),
		      &ui_yesno_radio("keep", 0), 1, $tds);

	# Multiple files
	print &ui_table_row(&hlink($text{'restore_multi'},"rmulti"),
		      &ui_yesno_radio("multi", 0), 1, $tds);

	# rmt path option
	print &ui_table_row(&hlink($text{'dump_rmt'},"rmt"),
		&ui_opt_textbox("rmt", $_[0]->{'rmt'}, 30, $text{'default'}),
		3, $tds);
	}
elsif ($_[0] eq 'xfs') {
	# xfs restore options

	# Target dir
	print &ui_table_row(&hlink($text{'restore_dir'},"rdir"),
		      &ui_textbox("dir", undef, 50)." ".
		      &file_chooser_button("dir", 1), 3, $tds);

	# Overwrite
	print &ui_table_row(&hlink($text{'restore_over'},"rover"),
		&ui_radio("over", 0, [ [ 0, $text{'restore_over0'} ],
				       [ 1, $text{'restore_over1'} ],
				       [ 2, $text{'restore_over2'} ] ]),
		3, $tds);

	# Attributes?
	print &ui_table_row(&hlink($text{'restore_noattribs'},"rnoattribs"),
		&ui_radio("noattribs", 0, [ [ 0, $text{'yes'} ],
					    [ 1, $text{'no'} ] ]), 1, $tds);

	# Label to restore from
	print &ui_table_row(&hlink($text{'restore_label'},"rlabel"),
		&ui_textbox("label", undef, 20), 1, $tds);
	}
else {
	# ext2/3 restore options
	print &ui_table_row(&hlink($text{'restore_rsh'},"rrsh"),
		      &rsh_command_input("rsh_def", "rsh", $_[1]->{'rsh'}),
		      3, $tds);

	# Password option for SSH
	print &ui_table_row(&hlink($text{'dump_pass2'},"passs"),
		      &ui_password("pass", $_[1]->{'pass'}, 20),
		      3, $tds);

	# Files to restore
	print &ui_table_row(&hlink($text{'restore_files'},"rfiles"),
		      &ui_opt_textbox("files", undef, 40, $text{'restore_all'},
				      $text{'restore_sel'}), 3, $tds);

	# Target dir
	print &ui_table_row(&hlink($text{'restore_dir'},"rdir"),
		      &ui_textbox("dir", undef, 50)." ".
		      &file_chooser_button("dir", 1), 3, $tds);

	# Multiple files
	print &ui_table_row(&hlink($text{'restore_multi'},"rmulti"),
		      &ui_yesno_radio("multi", 0), 1, $tds);
	}

# Show only
print &ui_table_row(&hlink($text{'restore_test'},"rtest"),
	      &ui_yesno_radio("test", 1), 1, $tds);
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
	&to_ipaddress($in{'host'}) ||
	    &to_ip6address($in{'host'}) ||
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
	$cmd .= " -J" if ($in{'gzip'} == 3);
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
	if (!$in{'rmt_def'}) {
		$in{'rmt'} =~ /^\S+$/ || &error($text{'dump_ermt'});
		$cmd .= " --rmt-command=".quotemeta($in{'rmt'});
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

