#!/usr/local/bin/perl
# smb_server.cgi
# Called in a pop-up javascript window to display a list of known SMB
# servers, by calling smbclient to request the browse list from some server

$trust_unknown_referers = 1;
require './mount-lib.pl';
use Socket;
&popup_header($text{'smb_choose'});
print <<EOF;
<script>
function choose(f)
{
top.opener.ifield.value = f;
window.close();
}
</script>
EOF

# call smbclient
$host = $config{'browse_server'} ? $config{'browse_server'} : "localhost";
&execute_command("$config{'smbclient_path'} -d 0 -L $host -N",
		 undef, \$out, \$out);
if ($?) {
	print "<b>",&text('smb_elist', $host),"</b>\n";
	exit;
	}
elsif ($out =~ /Unknown host/) {
	print "<b>",&text('smb_ehost', $host),"</b>\n";
	exit;
	}
elsif ($out =~ /error connecting|connect error/) {
	print "<b>",&text('smb_edown', $host),"</b>\n";
	exit;
	}

# parse server list
if ($out =~ /Server\s+Comment\n.*\n((.+\n)+)/) {
	@svlist = split(/\n/, $1);
	foreach $sv (@svlist) {
		if ($sv =~ /^\s+(\S+)\s*(.*)$/) {
			push(@names, $1); push(@comms, $2);
			}
		}
	}

if (@names) {
	print "<b>$text{'smb_sel'}</b><br>\n";
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'smb_name'}</b></td> ",
	      "<td><b>$text{'smb_desc'}</b></td> </tr>\n";
	for($i=0; $i<@names; $i++) {
		print "<tr $cb>\n";
		print "<td><a href=\"\" onClick='choose(\"$names[$i]\"); ",
		      "return false'>$names[$i]</a></td>\n";
		print "<td>$comms[$i]</td> </tr>\n";
		}
	print "</table>\n";
	}
else {
	print "<b>$text{'smb_none'}</b>.<p>\n";
	}

&popup_footer();


