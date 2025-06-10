# log_parser.pl
# Functions for parsing this module's logs

do 'proc-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($action eq 'run') {
	return &text('log_run', "<tt>".&html_escape($p->{'cmd'})."</tt>");
	}
elsif ($action eq 'kill') {
	local ($desc, $i);
	@pids = $p->{'pid'} ? ( $p->{'pid'} ) : split(/\s+/, $p->{'pidlist'});
	if ($long) {
		for($i=0; $i<@pids; $i++) {
			$desc .= "<i>".$p->{"args$i"}.
				 "</i>&nbsp;&nbsp;(PID $pids[$i])<br>";
			}
		return &text(@pids == 1 ? 'log_kill_l' : 'log_kills_l',
			     "<tt>$p->{'signal'}</tt>", $desc);
		}
	else {
		if (@pids == 1) {
			return &text('log_kill', "<tt>$p->{'signal'}</tt>",
				     $pids[0]);
			}
		else {
			return &text('log_kills', "<tt>$p->{'signal'}</tt>",
				     scalar(@pids));
			}
		}
	}
elsif ($action eq 'renice') {
	return &text('log_renice', $p->{'nice'}, $p->{'pid'});
	}
else {
	return undef;
	}
}

