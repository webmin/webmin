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
print &ui_table_row(&hlink($text{'dump_dest'}, "dest"),
   &ui_radio("mode", $_[0]->{'host'} ? 1 : 0,
	[ [ 0, $text{'dump_file'}." ".
	       &ui_textbox("file", $_[0]->{'file'}, 50).
	       " ".&file_chooser_button("file")."<br>" ],
	  [ 1, &text('dump_host',
		     &ui_textbox("host", $_[0]->{'host'}, 20),
		     &ui_textbox("huser", $_[0]->{'huser'}, 15),
		     &ui_textbox("hfile", $_[0]->{'hfile'}, 40)) ] ]), 3);

if ($_[0]->{'fs'} eq 'tar') {
	# Display gnutar options
	print &ui_table_row(&hlink($text{'dump_rsh'},"rsh"),
		&rsh_command_input("rsh_def", "rsh", $_[0]->{'rsh'}), 3);

	# Password option for SSH
	print &ui_table_row(&hlink($text{'dump_pass'},"pass"),
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

	print &ui_table_row(&hlink($text{'dump_gzip'},"gzip"),
			    &ui_select("gzip", int($_[0]->{'gzip'}),
				[ [ 0, $text{'no'} ],
				  [ 1, $text{'dump_gzip1'} ] ]), 1, $tds);

	print &ui_table_row(&hlink($text{'dump_multi'},"multi"),
			    &ui_yesno_radio("multi", int($_[0]->{'multi'})),
			    1, $tds);

	print &ui_table_row(&hlink($text{'dump_links'},"links"),
			    &ui_yesno_radio("links", int($_[0]->{'links'})),
			    1, $tds);

	print &ui_table_row(&hlink($text{'dump_xdev'},"xdev"),
			    &ui_yesno_radio("xdev", int($_[0]->{'xdev'})),
			    1, $tds);
	}
else {
	# Display ufs backup options
	print &ui_table_row(&hlink($text{'dump_update'},"update"),
			    &ui_yesno_radio("update", int($_[0]->{'update'})),
			    1, $tds);

	print &ui_table_row(&hlink($text{'dump_level'},"level"),
			    &ui_select("level", int($_[0]->{'level'}),
				[ map { [ $_, $text{'dump_level_'.$_} ] }
				      (0 .. 9) ]), 1, $tds);

	print &ui_table_row(&hlink($text{'dump_blocks'},"blocks"),
			    &ui_opt_textbox("blocks", $_[0]->{'blocks'}, 8,
					    $text{'dump_auto'})." kB",
			    3, $tds);

	print &ui_table_row(&hlink($text{'dump_honour'},"honour"),
			    &ui_yesno_radio("honour", int($_[0]->{'honour'})),
			    1, $tds);
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
	&to_ipaddress($in{'host'}) ||
	    &to_ip6address($in{'host'}) ||
		&error($text{'dump_ehost'});
	$_[0]->{'host'} = $in{'host'};
	$in{'huser'} =~ /^\S+$/ || &error($text{'dump_ehuser'});
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

# execute_dump(&dump, filehandle, escape, background-mode, [time])
# Executes a dump and displays the output
sub execute_dump
{
local $fh = $_[1];
local ($cmd, $flags);

if ($_[0]->{'huser'}) {
	$flags = "-f '$_[0]->{'huser'}\@$_[0]->{'host'}:".
		&date_subs($_[0]->{'hfile'}, $_[4])."'";
	}
elsif ($_[0]->{'host'}) {
	$flags = "-f '$_[0]->{'host'}:".&date_subs($_[0]->{'hfile'}, $_[4])."'";
	}
else {
	$flags = "-f '".&date_subs($_[0]->{'file'}, $_[4])."'";
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
	$cmd .= " -F \"$tapecmd $_[0]->{'id'}\""
		if (!$_[0]->{'gzip'} && ($_[0]->{'file'} =~ /^\/dev/ ||
					 $_[0]->{'hfile'} =~ /^\/dev/));
	$cmd .= " --rsh-command=$_[0]->{'rsh'}"
		if ($_[0]->{'rsh'} && $_[0]->{'host'});
	$cmd .= " $_[0]->{'extra'}" if ($_[0]->{'extra'});
	$cmd .= " ".quotemeta(&date_subs($_[0]->{'dir'}));
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
	$cmd .= " ".quotemeta(&date_subs($_[0]->{'dir'}));
	}

&system_logged("sync");
sleep(1);
$ENV{'DUMP_PASSWORD'} = $_[0]->{'pass'};
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
local ($fs, $dump, $tds) = @_;

# common options
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
				  [ 1, $text{'dump_gzip1'} ] ]), 1, $tds);

	print &ui_table_row(&hlink($text{'restore_keep'},"keep"),
		      &ui_yesno_radio("keep", 0), 1, $tds);

	# Multiple files
	print &ui_table_row(&hlink($text{'restore_multi'},"rmulti"),
		      &ui_yesno_radio("multi", 0), 1, $tds);

	# Show only
	print &ui_table_row(&hlink($text{'restore_test'},"rtest"),
		      &ui_yesno_radio("test", 1), 1, $tds);
	}
else {
	# ufs restore options, files to restore
	print &ui_table_row(&hlink($text{'restore_files'},"rfiles"),
		      &ui_opt_textbox("files", undef, 40, $text{'restore_all'},
				      $text{'restore_sel'}), 3, $tds);

	# Target dir
	print &ui_table_row(&hlink($text{'restore_dir'},"rdir"),
		      &ui_textbox("dir", undef, 50)." ".
		      &file_chooser_button("dir", 1), 3, $tds);

	# Show only
	print &ui_table_row(&hlink($text{'restore_nothing'},"rnothing"),
		      &ui_yesno_radio("nothing", 1), 1, $tds);
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
$ENV{'DUMP_PASSWORD'} = $in{'pass'};

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

