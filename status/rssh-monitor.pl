# rssh-monitor.pl
# Test a host by attempting to SSH into it

sub get_rssh_status
{
# Run the SSH command
&foreign_require("proc", "proc-lib.pl");
local $ruser = $_[0]->{'ruser'} || "root";
local ($fh, $fpid) = &proc::pty_process_exec(
	"ssh ".
	($_[0]->{'port'} ? "-p ".quotemeta($_[0]->{'port'})." " : "").
	quotemeta($ruser)."\@".
	quotemeta($_[0]->{'host'})." echo ok");
local ($out, $wrong_password, $connect_failed, $got_password);
while(1) {
	local $rv = &wait_for($fh, "password:|passphrase.*:", "yes\\/no", "(^|\\n)\\s*Permission denied.*\n", "ssh: connect.*\n", ".*\n");
	$out .= $wait_for_input;
	if ($rv == 0) {
		if ($_[0]->{'rpass'} eq '*') {
			# We got to the password phase, but aren't logging in
			$got_password = 1;
			last;
			}
		else {
			syswrite($fh, "$_[0]->{'rpass'}\n");
			}
		}
	elsif ($rv == 1) {
		syswrite($fh, "yes\n");
		}
	elsif ($rv == 2) {
		$wrong_password++;
		last;
		}
	elsif ($rv == 3) {
		$connect_failed++;
		}
	elsif ($rv < 0) {
		last;
		}
	}
close($fh);
kill('KILL', $fpid);
local $got = waitpid($fpid, 0);
if ($got_password) {
	return { 'up' => 1 };
	}
elsif ($wrong_password) {
	return { 'up' => 0,
		 'desc' => $text{'rssh_wrongpass'} };
	}
if ($connect_failed) {
	return { 'up' => 0,
		 'desc' => $text{'rssh_failed'} };
	}
if ($?) {
	return { 'up' => 0,
		 'desc' => $text{'rssh_error'} };
	}
return { 'up' => 1 };

}

sub show_rssh_dialog
{
print &ui_table_row($text{'rssh_host'},
		    &ui_textbox("host", $_[0]->{'host'}, 50), 3);

print &ui_table_row($text{'rssh_port'},
		    &ui_opt_textbox("port", $_[0]->{'port'}, 6,
				    $text{'default'}), 3);

print &ui_table_row($text{'rssh_ruser'},
		    &ui_textbox("ruser", $_[0]->{'ruser'}, 50), 3);

local $pmode = $_[0]->{'rpass'} eq '' ? 1 :
	       $_[0]->{'rpass'} eq '*' ? 2 : 0;
print &ui_table_row($text{'rssh_rpass'},
		    &ui_radio("rpass_def", $pmode,
		      [ [ 1, $text{'rssh_nopass'}."<br>" ],
			[ 2, $text{'rssh_nologin'}."<br>" ],
			[ 0, $text{'rssh_haspass'}." ".
			     &ui_textbox("rpass",
				$rpmode == 0 ? $_[0]->{'rpass'} : "", 30) ] ]));
}

sub parse_rssh_dialog
{
&has_command("ssh") || &error($text{'rssh_ecmd'});
&foreign_installed("proc") || &error($text{'rssh_eproc'});
$in{'host'} =~ /^[a-z0-9\.\-\_]+$/i || &error($text{'rssh_ehost'});
$_[0]->{'host'} = $in{'host'};
if ($in{'port_def'}) {
	delete($_[0]->{'port'});
	}
else {
	$in{'port'} =~ /^[1-9][0-9]*$/ || &error($text{'rssh_eport'});
	$_[0]->{'port'} = $in{'port'};
	}
$in{'rpass_def'} == 2 || $in{'ruser'} =~ /\S/ || &error($text{'rssh_eruser'});
$_[0]->{'ruser'} = $in{'ruser'};
$_[0]->{'rpass'} = $in{'rpass_def'} == 1 ? undef :
		   $in{'rpass_def'} == 2 ? '*' :
					   $in{'rpass'};
}

