# bind8-monitor.pl
# Monitor the BIND DNS server on this host

# Check the PID file to see if apache is running
sub get_bind8_status
{
return { 'up' => -1 } if (!&foreign_check($_[1]));
&foreign_require($_[1], "bind8-lib.pl");
local %bconfig = &foreign_config($_[1]);
return { 'up' => -1 }
	if (!-r &foreign_call($_[1], "make_chroot", $bconfig{'named_conf'}));
local $file = &foreign_call($_[1], "get_pid_file");
$file = &foreign_call($_[1], "make_chroot", $file, 1);

if (&check_pid_file($file)) {
	local @st = stat($file);
	return { 'up' => 1,
		 'desc' => &text('up_since', scalar(localtime($st[9]))) };
	}
else {
	return { 'up' => 0 };
	}
}

sub parse_bind8_dialog
{
&depends_check($_[0], "bind8");
}

1;

