#!/usr/local/bin/perl

require './dns-lib.pl';

&header("BIND 4 DNS Server", "", undef, 1, 1);
print &ui_hr();
%access = &get_module_acl();

# Check if named exists
if (!-x $config{'named_pathname'}) {
	print "<p>The BIND 4 DNS server <i>$config{'named_pathname'}</i>\n";
	print "could not be found on your system. Maybe it is not installed,\n";
	print "or your <a href=\"@{[&get_webprefix()]}/config.cgi?$module_name\">BIND 4 module\n";
	print "configuration</a> is incorrect. <p>\n";
	print &ui_hr();
	&footer("/", "index");
	exit;
	}

# Check for future versions of BIND with the -v option
$out = `$config{'named_pathname'} -v 2>&1`;
if (0 && ($out =~ /bind\s+(\d+)\./i || $out =~ /named\s+(\d+)\./) && $1 >= 8) {
	print "<p>The server <i>$config{'named_pathname'}</i> appears to\n";
	print "be BIND 8. Maybe your should use the\n";
	print "<a href=/bind8/>BIND 8 server module</a> instead. <p>\n";
	print &ui_hr();
	&footer("/", "index");
	exit;
	}

# Check if BIND is the right version.. Only BIND 8 offers the -f option
# Is there a better way to do this?
$out = `$config{'named_pathname'} -help 2>&1`;
if (0 && $out =~ /\[-f\]/) {
	print "<p>The server <i>$config{'named_pathname'}</i> appears to\n";
	print "be BIND 8. Maybe your should use the\n";
	print "<a href=/bind8/>BIND 8 server module</a> instead. <p>\n";
	print &ui_hr();
	&footer("/", "index");
	exit;
	}

# If the named.boot file is empty or does not exist, offer to create it
if (!-r $config{named_boot_file}) { $need_create++; }
else {
	$conf = &get_config();
	if (!@$conf) { $need_create++; }
	}

if ($need_create) {
	# There is no nameserver boot file.. offer to create
	print "<p>The primary configuration file\n";
	print "<i>$config{named_boot_file}</i> does not exist,\n";
	print "or is empty. Create it?<p>\n";
	print "<form action=\"dns_boot.cgi\">\n";
	print "<input type=radio name=real value=0> Setup nameserver for ",
	      "internal non-internet use only<p>\n";
	print "<input type=radio name=real value=1 checked> Setup as an ",
	      "internet name server, and download root server information<p>\n";
	print "<input type=radio name=real value=2> Setup as an internet name ",
	      "server, but use Webmin's older root server information<p>\n";
	print "<center><input type=submit value=\"Create Primary Configuration File and Start Nameserver\"></center>\n";
	print "</form>\n";
	print &ui_hr();
	&footer("/", "index");
	exit;
	}

@zlist = (&find_config("primary", $conf), &find_config("secondary", $conf));
if (!@zlist) {
	# Nothing in named file..
	print "<b>There are no DNS zones defined for this name server</b><p>\n";
	}
else {
	print &ui_subheading("Existing DNS Zones");
	foreach $z (@zlist) {
		next if (!&can_edit_zone(\%access, $z->{'values'}->[0]));
		if ($z->{'name'} eq "primary") {
			push(@zlinks, "edit_master.cgi?index=$z->{'index'}");
			push(@ztitles, &arpa_to_ip($z->{'values'}->[0]));
			push(@zicons, "../bind8/images/master.gif");
			push(@ztypes, "Master");
			}
		else {
			push(@zlinks, "edit_slave.cgi?index=$z->{'index'}");
			push(@ztitles, &arpa_to_ip($z->{'values'}->[0]));
			push(@zicons, "../bind8/images/slave.gif");
			push(@ztypes, "Slave");
			}
		$len++;
		}

	# sort list of zones
	@zorder = sort { $ztitles[$a] cmp $ztitles[$b] } (0 .. $len-1);
	@zlinks = map { $zlinks[$_] } @zorder;
	@ztitles = map { $ztitles[$_] } @zorder;
	@zicons = map { $zicons[$_] } @zorder;
	@ztypes = map { $ztypes[$_] } @zorder;

	if ($config{'show_list'}) {
		# display as list
		$mid = int((@zlinks+1)/2);
		print "<table width=100%><tr><td width=50% valign=top>\n";
		&zones_table([ @zlinks[0 .. $mid-1] ],
			     [ @ztitles[0 .. $mid-1] ],
			     [ @ztypes[0 .. $mid-1] ]);
		print "</td><td width=50% valign=top>\n";
		if ($mid < @zlinks) {
			&zones_table([ @zlinks[$mid .. $#zlinks] ],
				     [ @ztitles[$mid .. $#ztitles] ],
				     [ @ztypes[$mid .. $#ztypes] ]);
			}
		print "</td></tr></table>\n";
		}
	else {
		# display as icons
		&icons_table(\@zlinks, \@ztitles, \@zicons);
		}
	}
if ($access{'master'}) {
	print "<a href=\"master_form.cgi\">Create a new ",
	      "master zone</a>&nbsp;&nbsp;\n";
	}
if ($access{'slave'}) {
	print "<a href=\"slave_form.cgi\">Create a new ",
	      "slave zone</a>&nbsp;&nbsp;\n";
	}
print "<p>\n";

if ($access{'defaults'}) {
	# Display form to set the defaults for new zones
	&get_zone_defaults(\%zd);
	print &ui_hr();
	print &ui_subheading("New Master Zone Defaults");
	print "<form action=save_zonedef.cgi>\n";
	print "<table border>\n";
	print "<tr $tb> <td><b>Defaults for new master zones</b></td> </tr>\n";
	print "<tr $cb> <td><table cellpadding=5>\n";

	print "<tr> <td><b>Refresh time</b></td>\n";
	print "<td><input name=refresh size=10 value=$zd{'refresh'}> seconds</td>\n";
	print "<td><b>Transfer retry time</b></td>\n";
	print "<td><input name=retry size=10 value=$zd{'retry'}> seconds</td></tr>\n";

	print "<tr> <td><b>Expiry time</b></td>\n";
	print "<td><input name=expiry size=10 value=$zd{'expiry'}> seconds</td>\n";
	print "<td><b>Default time-to-live</b></td>\n";
	print "<td><input name=minimum size=10 value=$zd{'minimum'}> seconds</td>\n";
	print "</tr> </table></td></tr></table><br>\n";
	print "<input type=submit value=Update></form>\n";
	}

# Display a form to start or restart named
print &ui_hr();
if ($config{'named_pid_file'}) {
	if (open(PID, $config{'named_pid_file'})) {
		<PID> =~ /(\d+)/;
		$pid = $1;
		close(PID);
		}
	}
else {
	&foreign_require("proc", "proc-lib.pl");
	foreach $p (&proc::list_processes()) {
		if ($p->{'args'} =~ /^\Q$config{'named_pathname'}\E/) {
			$pid = $p->{'pid'};
			last;
			}
		}
	}
if ($pid && kill(0, $pid)) {
        # named is running
        print "<form action=restart.cgi>\n";
        print "<input type=hidden name=pid value=$pid>\n";
        print "<table width=100%><tr><td>\n";
        print "<input type=submit value=\"Apply Changes\"></td>\n";
        print "<td>Click this button to restart the running BIND 4 server.\n";
        print "This will cause the current configuration to become\n";
        print "active</td> </tr></table>\n";
        print "</form>\n";
        }
else {
        # named is not running
        print "<form action=start.cgi>\n";
        print "<table width=100%><tr><td>\n";
        print "<input type=submit value=\"Start Name Server\"></td>\n";
        print "<td>Click this button to start the BIND 4 server, and load\n";
        print "the current configuration</td> </tr></table>\n";
        print "</form>\n";
        }

print &ui_hr();
&footer("/", "index");

sub zones_table
{
local($i);
print "<table border width=100%>\n";
print "<tr $tb> <td><b>Zone</b></td> <td><b>Type</b></td> </tr>\n";
for($i=0; $i<@{$_[0]}; $i++) {
	print "<tr $cb>\n";
	print "<td><a href=\"$_[0]->[$i]\">$_[1]->[$i]</a></td>\n";
	print "<td>$_[2]->[$i]</td>\n";
	print "</tr>\n";
	}
print "</table>\n";
}

