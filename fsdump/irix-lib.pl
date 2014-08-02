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
# Display destination options
print &ui_table_row(&hlink($text{'dump_dest'}, "dest"),
   &ui_radio("mode", $_[0]->{'host'} ? 1 : 0,
	[ [ 0, $text{'dump_file'}." ".
	       &ui_textbox("file", $_[0]->{'file'}, 50).
	       " ".&file_chooser_button("file")."<br>" ],
	  [ 1, &text('dump_host',
		     &ui_textbox("host", $_[0]->{'host'}, 15),
		     &ui_textbox("huser", $_[0]->{'huser'}, 8),
		     &ui_textbox("hfile", $_[0]->{'hfile'}, 20)) ] ]), 3);
}

sub dump_options_form
{
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
	$_[0]->{'huser'} = $in{'huser'};
	$in{'hfile'} || &error($text{'dump_ehfile'});
	$_[0]->{'hfile'} = $in{'hfile'};
	delete($_[0]->{'file'});
	}

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

# execute_dump(&dump, filehandle, escape, background-mode, [time])
# Executes a dump and displays the output
sub execute_dump
{
local $fh = $_[1];
local ($cmd, $flag);
if ($_[0]->{'huser'}) {
	$flag = " -f '$_[0]->{'huser'}\@$_[0]->{'host'}:".
		&date_subs($_[0]->{'hfile'}, $_[4])."'";
	}
elsif ($_[0]->{'host'}) {
	$flag = " -f '$_[0]->{'host'}:".&date_subs($_[0]->{'hfile'}, $_[4])."'";
	}
else {
	$flag = " -f '".&date_subs($_[0]->{'file'}, $_[4])."'";
	}
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
$cmd .= " '".&date_subs($_[0]->{'dir'})."'";

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
# Restore from
print &ui_table_row(&hlink($text{'restore_src'}, "rsrc"),
   &ui_radio("mode", $_[1]->{'host'} ? 1 : 0,
	[ [ 0, $text{'dump_file'}." ".
	       &ui_textbox("file", $_[1]->{'file'}, 50).
	       " ".&file_chooser_button("file")."<br>" ],
	  [ 1, &text('dump_host',
		     &ui_textbox("host", $_[1]->{'host'}, 15),
		     &ui_textbox("huser", $_[1]->{'huser'}, 8),
		     &ui_textbox("hfile", $_[1]->{'hfile'}, 20)) ] ]), 3, $tds);

# Target dir
print &ui_table_row(&hlink($text{'restore_dir'},"rdir"),
	      &ui_textbox("dir", undef, 50)." ".
	      &file_chooser_button("dir", 1), 3, $tds);

# Overwrite
print &ui_table_row(&hlink($text{'restore_over'},"rover"),
	&ui_radio("over", 0, [ [ 0, $text{'restore_over0'} ],
			       [ 1, $text{'restore_over1'} ],
			       [ 2, $text{'restore_over2'} ] ]), 3, $tds);

# Attributes?
print &ui_table_row(&hlink($text{'restore_noattribs'},"rnoattribs"),
	&ui_radio("noattribs", 0, [ [ 0, $text{'yes'} ],
				    [ 1, $text{'no'} ] ]), 1, $tds);

# Label to restore from
print &ui_table_row(&hlink($text{'restore_label'},"rlabel"),
	&ui_textbox("label", undef, 20), 1, $tds);

# Show only
print &ui_table_row(&hlink($text{'restore_test'},"rtest"),
	      &ui_yesno_radio("test", 1), 1, $tds);
}

# parse_restore(filesystem)
# Parses inputs from restore_form() and returns a command to be passed to
# restore_backup()
sub parse_restore
{
local $cmd = "xfsrestore";
$cmd .= " -t" if ($in{'test'});
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

