#!/usr/local/bin/perl
# smb_share.cgi
# Displays a list of shares available on some host

require './mount-lib.pl';
&ReadParse();
$access{'browse'} || &error($text{'browse_ecannot'});
$hserver = &html_escape($in{'server'});
&header(&text('smb_choose2', $hserver));
print <<EOF;
<script>
function choose(f)
{
top.opener.ifield.value = f;
window.close();
}
</script>
EOF

# A leading dash would be read as an smbclient option
$in{'server'} =~ /^-/ && &error(&text('smb_ehost', $hserver));
my $qserver = quotemeta($in{'server'});
&execute_command("$config{'smbclient_path'} -d 0 -L $qserver -N",
		 undef, \$out, \$out);
if ($?) {
	print "<b>",&text('smb_elist2', $hserver),"</b>\n";
	exit;
	}
elsif ($out =~ /Unknown host/) {
	print "<b>",&text('smb_ehost', $hserver),"</b>\n";
	exit;
	}
elsif ($out =~ /error connecting|connect error/) {
	print "<b>",&text('smb_edown', $hserver),"</b>\n";
	exit;
	}

if ($out =~ /Sharename\s+Type\s+Comment\n((.+\n)+)/) {
	@shlist = split(/\n/, $1);
	foreach $sh (@shlist) {
		if ($sh =~ /^\s+(.{1,7}\S+)\s+Disk\s*(.*)$/) {
			push(@names, $1); push(@comms, $2);
			}
		}
	}
if (@names) {
	print "<b>$text{'smb_sel2'}</b><p>\n";
	print &ui_columns_start([ $text{'smb_share'},
				  $text{'smb_comment'} ]);
	for($i=0; $i<@names; $i++) {
		print &ui_columns_row([
			# Share names come from the remote server
			&ui_link("#", &html_escape($names[$i]), undef,
				 "onClick='choose(\"".
				 &quote_javascript($names[$i]).
				 "\");return false;'"),
			&html_escape($comms[$i]),
			]);
		}
	print &ui_columns_end();
	}
else {
	print "<b>",&text('smb_noshares', $hserver),"</b><p>\n";
	}

&popup_footer();

