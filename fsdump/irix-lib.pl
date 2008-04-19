# irix-lib.pl

# supported_filesystems()
# Returns a list of filesystem types on which dumping is supported
sub supported_filesystems
{
local @rv;
push(@rv, "xfs") if (&has_command("xfsdump"));
return @rv;
}

# multiple_directory_support(fs)
# Returns 1 if some filesystem dump supports multiple directories
sub multiple_directory_support
{
return 0;
}

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
}

sub dump_options_form
{
if ($_[0]->{'fs'} eq 'xfs') {
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
	}
else {
	# Display efs filesystem dump options
	# XXX not done!
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

	if ($dump_version >= 0.424) {
		print "<tr> <td><b>",&hlink($text{'dump_comp'},"comp"),
		      "</b></td> <td colspan=3>\n";
		printf "<input name=comp_def type=radio value=1 %s> %s\n",
			$_[0]->{'comp'} ? '' : 'checked', $text{'no'};
		printf "<input name=comp_def type=radio value=0 %s> %s\n",
			$_[0]->{'comp'} ? 'checked' : '',$text{'dump_complvl'};
		printf "<input name=comp size=4 value='%s'></td>\n",
			$_[0]->{'comp'} || 2;
		}
	}
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

if ($_[0]->{'fs'} eq 'xfs') {
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
	}
else {
	# Parse efs options
	# XXX not done!
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
	if ($in{'comp_def'} || !defined($in{'comp'})) {
		delete($_[0]->{'comp'});
		}
	else {
		$in{'comp'} =~ /^[1-9]\d*$/ || &error($text{'dump_ecomp'});
		$_[0]->{'comp'} = $in{'comp'};
		}
	}

}

# execute_dump(&dump, filehandle, escape)
# Executes a dump and displays the output
sub execute_dump
{
local $fh = $_[1];
local ($cmd, $flag);
if ($_[0]->{'huser'}) {
	$flag = " -f '$_[0]->{'huser'}\@$_[0]->{'host'}:".
		&date_subs($_[0]->{'hfile'})."'";
	}
elsif ($_[0]->{'host'}) {
	$flag = " -f '$_[0]->{'host'}:".&date_subs($_[0]->{'hfile'})."'";
	}
else {
	$flag = " -f '".&date_subs($_[0]->{'file'})."'";
	}
if ($_[0]->{'fs'} eq 'xfs') {
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
	$cmd .= " -c \"$_[3] $_[0]->{'id'}\"" if ($_[3]);
	$cmd .= " -E -F" if ($_[0]->{'erase'});
	$cmd .= " $_[0]->{'extra'}" if ($_[0]->{'extra'});
	$cmd .= " '$_[0]->{'dir'}'";
	}
else {
	# efs backup
	# XXX not done!
	$cmd = "dump -$_[0]->{'level'}";
	$cmd .= $flag;
	$cmd .= " -u" if ($_[0]->{'update'});
	$cmd .= " -M" if ($_[0]->{'multi'});
	$cmd .= " -L '$_[0]->{'label'}'" if ($_[0]->{'label'});
	$cmd .= " -B $_[0]->{'blocks'}" if ($_[0]->{'blocks'});
	$cmd .= " -j$_[0]->{'comp'}" if ($_[0]->{'comp'});
	$cmd .= " $_[0]->{'extra'}" if ($_[0]->{'extra'});
	$cmd .= " '$_[0]->{'dir'}'";
	}

&system_logged("sync");
sleep(1);
&additional_log('exec', undef, $cmd);
&open_execute_command(CMD, "$cmd 2>&1 </dev/null", 1);
while(<CMD>) {
	if ($_[2]) {
		print $fh &html_escape($_);
		}
	else {
		print $fh $_;
		}
	}
close(CMD);
return $? ? 0 : 1;
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

# restore_form(filesystem)
sub restore_form
{
# common options
print "<tr> <td valign=top><b>",&hlink($text{'restore_src'}, "rsrc"),
      "</b></td>\n";
printf "<td colspan=3><input type=radio name=mode value=0 %s> %s\n",
        $_[1]->{'host'} ? "" : "checked", $text{'dump_file'};
printf "<input name=file size=50 value='%s'> %s<br>\n",
        $_[1]->{'host'} ? "" : $_[0]->{'file'}, &file_chooser_button("file");
printf "<input type=radio name=mode value=1 %s>\n",
        $_[1]->{'host'} ? "checked" : "";
print &text('dump_host',
            "<input name=host size=15 value='$_[1]->{'host'}'>",
            "<input name=huser size=8 value='$_[1]->{'huser'}'>",
            "<input name=hfile size=20 value='$_[1]->{'hfile'}'>"),
      "</td> </tr>\n";

if ($_[0] eq 'xfs') {
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
	# efs restore options
	# XXX not done!
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
if ($_[0] eq 'xfs') {
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
if ($_[0] eq 'xfs') {
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
	# parse efs options
	# XXX not done!
	$cmd .= " -M" if ($in{'multi'});
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
if ($_[0] eq 'xfs') {
	# Just run the backup command
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
		local $rv = &wait_for($fh, "(next volume #)", "(set owner.mode for.*\\[yn\\])", "((.*)\\[yn\\])", "(.*\\n)");
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
		}
	close($fh);
	waitpid($fpid, 0);
	return $? || undef;
	}
}

1;

