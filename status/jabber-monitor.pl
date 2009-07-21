# jabber-monitor.pl
# Monitor the jabber server on this host

# Check the PID file to see if mon is running
sub get_jabber_status
{
return { 'up' => -1 } if (!&foreign_check($_[1]));
local %jconfig = &foreign_config($_[1]);
-r $jconfig{'jabber_config'} || return { 'up' => -1 };
&foreign_require($_[1], "jabber-lib.pl");
local $pidfile = &foreign_call($_[1], "jabber_pid_file");
if (open(PID, $pidfile) && ($pid = int(<PID>)) && kill(0, $pid)) {
	return { 'up' => 1 };
	}
else {
	return { 'up' => 0 };
	}
}

sub parse_jabber_dialog
{
&depends_check($_[0], "jabber");
eval "use XML::Parser";
&error(&text('jabber_eparser', "<tt>XML::Parser</tt>")) if ($@);
}

1;

