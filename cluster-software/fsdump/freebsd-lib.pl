# freebsd-lib.pl

# supported_filesystems()
# Returns a list of filesystem types on which dumping is supported
sub supported_filesystems
{
local @rv;
push(@rv, "ufs") if (&has_command("dump"));
return @rv;
}

# multiple_directory_support(fs)
# Returns 1 if some filesystem dump supports multiple directories
sub multiple_directory_support
{
return 0;
}

$supports_tar = 1;
$tar_command = &has_command("gtar") || &has_command("tar");

# dump_form(&dump)
sub dump_form
{
# Display common options
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

if ($_[0]->{'fs'} eq 'tar') {
	# Display gnutar options
	print "<tr> <td><b>",&hlink($text{'dump_rsh'},"rsh"),
	      "</b></td>\n";
	print "<td colspan=3>",
	      &rsh_command_input("rsh_def", "rsh", $_[0]->{'rsh'}),
	      "</td> </tr>\n";

	# Password option for SSH
	print "<tr> <td><b>",&hlink($text{'dump_pass'},"pass"),
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
	printf "<td><input name=gzip type=radio value=1 %s> %s\n",
		$_[0]->{'gzip'} ? 'checked' : '', $text{'yes'};
	printf "<input name=gzip type=radio value=0 %s> %s</td>\n",
		$_[0]->{'gzip'} ? '' : 'checked', $text{'no'};

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
	}
else {
	# Display ufs backup options
	print "<tr> <td><b>",&hlink($text{'dump_update'},"update"),
	      "</b></td>\n";
	printf "<td><input name=update type=radio value=1 %s> %s\n",
		$_[0]->{'update'} ? 'checked' : '', $text{'yes'};
	printf "<input name=update type=radio value=0 %s> %s</td>\n",
		$_[0]->{'update'} ? '' : 'checked', $text{'no'};

	print "<td><b>",&hlink($text{'dump_level'},"level"),"</b></td>\n";
	print "<td><select name=level>\n";
	foreach $l (0 .. 9) {
		printf "<option value=%d %s>%d %s\n",
			$l, $_[0]->{'level'} == $l ? "selected" : "", $l,
			$text{'dump_level_'.$l};
		}
	print "</select></td> </tr>\n";

	print "<tr> <td><b>",&hlink($text{'dump_blocks'},"blocks"),
	      "</b></td> <td colspan=3>\n";
	printf "<input name=blocks_def type=radio value=1 %s> %s\n",
		$_[0]->{'blocks'} ? '' : 'checked', $text{'dump_auto'};
	printf "<input name=blocks_def type=radio value=0 %s>\n",
		$_[0]->{'blocks'} ? 'checked' : '';
	printf "<input name=blocks size=8 value='%s'> kB</td> </tr>\n",
		$_[0]->{'blocks'};

	print "<tr><td><b>",&hlink($text{'dump_honour'},"honour"),"</b></td>\n";
	printf "<td><input name=honour type=radio value=1 %s> %s\n",
		$_[0]->{'honour'} ? 'checked' : '', $text{'yes'};
	printf "<input name=honour type=radio value=0 %s> %s</td>\n",
		$_[0]->{'honour'} ? '' : 'checked', $text{'no'};
	}

print "</tr>\n";
}

# parse_dump(&dump)
sub parse_dump
{
# Parse common options
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
	$in{'huser'} =~ /^\S+$/ || &error($text{'dump_ehuser'});
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
		}
	}
else {
	# Parse ufs options
	local $mp;
	foreach $m (&foreign_call("mount", "list_mounted")) {
		$mp++ if ($m->[0] eq $in{'dir'});
		}
	$mp || &error($text{'dump_emp'});

	$_[0]->{'update'} = $in{'update'};
	$_[0]->{'level'} = $in{'level'};
	$_[0]->{'honour'} = $in{'honour'};
	if ($in{'blocks_def'}) {
		delete($_[0]->{'blocks'});
		}
	else {
		$in{'blocks'} =~ /^\d+$/ || &error($text{'dump_eblocks'});
		$_[0]->{'blocks'} = $in{'blocks'};
		}
	}
}

# execute_dump(&dump, filehandle, escape)
# Executes a dump and displays the output
sub execute_dump
{
local $fh = $_[1];
local ($cmd, $flags);

if ($_[0]->{'huser'}) {
	$flags = "-f '$_[0]->{'huser'}\@$_[0]->{'host'}:".
		&date_subs($_[0]->{'hfile'})."'";
	}
elsif ($_[0]->{'host'}) {
	$flags = "-f '$_[0]->{'host'}:".&date_subs($_[0]->{'hfile'})."'";
	}
else {
	$flags = "-f '".&date_subs($_[0]->{'file'})."'";
	}
local $tapecmd = $_[0]->{'multi'} && $_[0]->{'fs'} eq 'tar' ? $multi_cmd :
		 $_[0]->{'multi'} ? undef :
		 $_[3] && !$config{'nonewtape'} ? $newtape_cmd : $notape_cmd;
if ($_[0]->{'fs'} eq 'tar') {
	# Construct tar command
	$cmd = "$tar_command -c $flags";
	$cmd .= " -V '$_[0]->{'label'}'" if ($_[0]->{'label'});
	$cmd .= " -L $_[0]->{'blocks'}" if ($_[0]->{'blocks'});
	$cmd .= " -z" if ($_[0]->{'gzip'});
	$cmd .= " -M" if ($_[0]->{'multi'});
	$cmd .= " -h" if ($_[0]->{'links'});
	$cmd .= " -l" if ($_[0]->{'xdev'});
	$cmd .= " -F \"$tapecmd $_[0]->{'id'}\"" if (!$_[0]->{'gzip'});
	$cmd .= " --rsh-command=$_[0]->{'rsh'}" if ($_[0]->{'rsh'});
	$cmd .= " $_[0]->{'extra'}" if ($_[0]->{'extra'});
	$cmd .= " '$_[0]->{'dir'}'";
	}
else {
	# Construct ufs dump command
	$cmd = "dump -$_[0]->{'level'} $flags";
	$cmd .= " -u" if ($_[0]->{'update'});
	if ($_[0]->{'blocks'}) {
		$cmd .= " -B $_[0]->{'blocks'}";
		}
	else {
		$cmd .= " -a";
		}
	$cmd .= " -h 0" if ($_[0]->{'honour'});
	$cmd .= " $_[0]->{'extra'}" if ($_[0]->{'extra'});
	$cmd .= " '$_[0]->{'dir'}'";
	}

&system_logged("sync");
sleep(1);
local $got = &run_ssh_command($cmd, $fh, $_[2], $_[0]->{'pass'});
if ($_[0]->{'multi'} && $_[0]->{'fs'} eq 'tar') {
	# Run multi-file switch command one last time
	&execute_command("$multi_cmd $_[0]->{'id'} >/dev/null 2>&1");
	}
return $got ? 0 : 1;
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
return &has_command("restore") ? undef : $cmd;
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
	print "<tr> <td><b>",&hlink($text{'dump_pass'},"pass"),
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
	print "<td><input type=radio name=gzip value=1> $text{'yes'}\n";
	print "<input type=radio name=gzip value=0 checked> $text{'no'}</td> </tr>\n";

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

	}
else {
	# ufs restore options
	print "<tr> <td><b>",&hlink($text{'restore_files'},"rfiles"),
	      "</b></td>\n";
	print "<td colspan=3><input type=radio name=files_def value=1 checked> ",
	      "$text{'restore_all'}\n";
	print "<input type=radio name=files_def value=0> $text{'restore_sel'}\n";
	print "<input name=files size=40></td> </tr>\n";

	print "<tr> <td><b>",&hlink($text{'restore_dir'},"rdir"),"</td>\n";
	print "<td colspan=3><input name=dir size=40> ",
		&file_chooser_button("dir", 1),"</td> </tr>\n";

	print "<tr> <td><b>",&hlink($text{'restore_nothing'},"rnothing"),
	      "</b></td>\n";
	print "<td><input type=radio name=nothing value=1> $text{'yes'}\n";
	print "<input type=radio name=nothing value=0 checked> $text{'no'}</td>\n";

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
if ($_[0] eq "tar") {
	$cmd = $tar_command;
	if ($in{'test'}) {
		$cmd .= " -t -v";
		}
	else {
		$cmd .= " -x";
		}
	}
else {
	$cmd .= "restore".($in{'test'} ? " -t" : " -x");
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
	$cmd .= " -z" if ($in{'gzip'});
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
else {
	# parse ufs options
	$cmd .= " -N" if ($in{'nothing'});
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

# Need to supply prompts
&foreign_require("proc", "proc-lib.pl");
local ($fh, $fpid) = &foreign_call("proc", "pty_process_exec", "cd '$in{'dir'}' ; $_[1]");
local $donevolume;
while(1) {
	local $rv = &wait_for($fh, "(next volume #)", "(set owner.mode for.*\\[yn\\])", "((.*)\\[yn\\])", "password:", "yes\\/no", "(.*\\n)");
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
	elsif ($rv == 2) {
		return &text('restore_equestion',
			     "<tt>$matches[2]</tt>");
		}
	elsif ($rv == 3) {
		syswrite($fh, "$in{'pass'}\n");
		}
	elsif ($rv == 4) {
		syswrite($fh, "yes\n");
		}
	}
close($fh);
waitpid($fpid, 0);
return $? || undef;
}

1;

