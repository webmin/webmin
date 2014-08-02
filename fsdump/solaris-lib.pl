# solaris-lib.pl

# supported_filesystems()
# Returns a list of filesystem types on which dumping is supported
sub supported_filesystems
{
local @rv;
push(@rv, "ufs") if (&has_command("ufsdump"));
return @rv;
}

# multiple_directory_support(fs)
# Returns 1 if some filesystem dump supports multiple directories
sub multiple_directory_support
{
return $_[0] eq "ufs";
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
local ($dump, $tds) = @_;

print &ui_table_row(&hlink($text{'dump_update'},"update"),
		    &ui_yesno_radio("update", int($_[0]->{'update'})),
		    1, $tds);

print &ui_table_row(&hlink($text{'dump_verify'},"verify"),
		    &ui_yesno_radio("verify", int($_[0]->{'verify'})),
		    1, $tds);

print &ui_table_row(&hlink($text{'dump_level'},"level"),
		    &ui_select("level", int($_[0]->{'level'}),
			[ map { [ $_, $text{'dump_level_'.$_} ] }
			      (0 .. 9) ]), 1, $tds);

print &ui_table_row(&hlink($text{'dump_offline'},"offline"),
		    &ui_yesno_radio("offline", int($_[0]->{'offline'})),
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

$_[0]->{'update'} = $in{'update'};
$_[0]->{'verify'} = $in{'verify'};
$_[0]->{'level'} = $in{'level'};
$_[0]->{'offline'} = $in{'offline'};
}

# execute_dump(&dump, filehandle, escape, background-mode, [time])
# Executes a dump and displays the output
sub execute_dump
{
local $fh = $_[1];
local $cmd = "ufsdump $_[0]->{'level'}";
$cmd .= "u" if ($_[0]->{'update'});
$cmd .= "v" if ($_[0]->{'verify'});
$cmd .= "o" if ($_[0]->{'offline'});
if ($_[0]->{'huser'}) {
	$cmd .= "f '$_[0]->{'huser'}\@$_[0]->{'host'}:".
		&date_subs($_[0]->{'hfile'}, $_[4])."'";
	}
elsif ($_[0]->{'host'}) {
	$cmd .= "f '$_[0]->{'host'}:".&date_subs($_[0]->{'hfile'}, $_[4])."'";
	}
else {
	$cmd .= "f '".&date_subs($_[0]->{'file'}, $_[4])."'";
	}
$cmd .= " $_[0]->{'extra'}" if ($_[0]->{'extra'});
local @dirs = $_[0]->{'tabs'} ? split(/\t+/, $_[0]->{'dir'})
			      : split(/\s+/, $_[0]->{'dir'});
@dirs = map { &date_subs($_) } @dirs;
$cmd .= " ".join(" ", map { "'$_'" } @dirs);

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
return &has_command("ufsrestore") ? undef : "ufsrestore";
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

# Files to restore
print &ui_table_row(&hlink($text{'restore_files'},"rfiles"),
	      &ui_opt_textbox("files", undef, 40, $text{'restore_all'},
			      $text{'restore_sel'}), 3, $tds);

# Target dir
print &ui_table_row(&hlink($text{'restore_dir'},"rdir"),
	      &ui_textbox("dir", undef, 50)." ".
	      &file_chooser_button("dir", 1), 3, $tds);

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
$cmd = "ufsrestore";
$cmd .= ($in{'test'} ? " t" : " x");
if ($in{'mode'} == 0) {
	$in{'file'} || &error($text{'restore_efile'});
	$cmd .= "f '$in{'file'}'";
	}
else {
	&to_ipaddress($in{'host'}) ||
	    &to_ip6address($in{'host'}) ||
		&error($text{'restore_ehost'});
	$in{'huser'} =~ /^\S*$/ || &error($text{'restore_ehuser'});
	$in{'hfile'} || &error($text{'restore_ehfile'});
	if ($in{'huser'}) {
		$cmd .= "f '$in{'huser'}\@$in{'host'}:$in{'hfile'}'";
		}
	else {
		$cmd .= "f '$in{'host'}:$in{'hfile'}'";
		}
	}

$cmd .= " $in{'extra'}" if ($in{'extra'});
if (!$in{'files_def'}) {
	$in{'files'} || &error($text{'restore_efiles'});
	$cmd .= " $in{'files'}";
	}
-d $in{'dir'} || &error($text{'restore_edir'});

return $cmd;
}

# restore_backup(filesystem, command)
# Restores a backup based on inputs from restore_form(), and displays the results
sub restore_backup
{
&additional_log('exec', undef, $_[1]);

&foreign_require("proc", "proc-lib.pl");
local ($fh, $fpid) = &foreign_call("proc", "pty_process_exec", "cd '$in{'dir'}' ; $_[1]");
local $donevolume;
while(1) {
	local $rv = &wait_for($fh, "(next volume #)", "(set owner.mode for.*\\[yn\\])", "(Directories already exist, set modes anyway. \\[yn\\])", "((.*)\\[yn\\])", "(.*\\n)");
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
	elsif ($rv == 1 || $rv == 2) {
		syswrite($fh, "n\n", 2);
		}
	elsif ($rv == 3) {
		return &text('restore_equestion',
			     "<tt>$matches[2]</tt>");
		}
	}
close($fh);
waitpid($fpid, 0);
return $? || undef;
}

1;

