#!/usr/local/bin/perl
# smb_server.cgi
# Called in a pop-up javascript window to display a list of known SMB
# servers, by calling smbclient to request the browse list from some server

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
if ($config{'browse_server'} eq "*") {
	# Get from workgroup
	if ($config{'browse_group'}) {
		# Find master for workgroup
		$out = &backquote_command(
			$config{'nmblookup_path'}." -N ".
			$config{'browse_group'}." 2>&1 </dev/null");
		if ($out =~ /(^|\n)([0-9\.]+)\s/) {
			$host = $2;
			}
		else {
			print "<b>",&text('smb_emaster', $config{'browse_group'}),"</b>\n";
			exit;
			}
		}
	else {
		# No idea what to do
		print "<b>",&text('smb_eworkgroup'),"</b>\n";
		exit;
		}
	}
elsif ($config{'browse_server'}) {
	# Fixed host
	$host = $config{'browse_server'};
	}
else {
	# Poll local samba
	$host = "localhost";
	}
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
	print "<b>$text{'smb_sel'}</b><p>\n";
	print &ui_columns_start([ $text{'smb_name'}, $text{'smb_desc'} ]);
	for($i=0; $i<@names; $i++) {
		print &ui_columns_row([
            &ui_link("#", $names[$i], undef, "onClick='choose(\"$names[$i]\");return false;'"),
			&html_escape($comms[$i])
			]);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'smb_none'}</b>.<p>\n";
	}

&popup_footer();


