# pptp-client-lib.pl
# XXX help page

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
do 'secrets-lib.pl';

# list_tunnels()
# Returns a list of the details of configured tunnels, in the format used
# by the pptp-command script
sub list_tunnels
{
local ($f, @rv);
opendir(DIR, $config{'peers_dir'});
while($f = readdir(DIR)) {
	next if ($f =~ /^\./ || $f eq "__default");
	local @opts = &parse_ppp_options("$config{'peers_dir'}/$f");
	local ($pptp) = grep { $_->{'comment'} =~ /^PPTP/ } @opts;
	if ($pptp) {
		# Is a tunnel config .. add it
		push(@rv, { 'name' => $f,
			    'file' => "$config{'peers_dir'}/$f",
			    'opts' => \@opts });
		}
	}
closedir(DIR);
return @rv;
}

# parse_ppp_options(file)
sub parse_ppp_options
{
local @rv;
local $lnum = 0;
open(OPTS, $_[0]);
while(<OPTS>) {
	s/\r|\n//g;
	if (/^#\s*(.*)/) {
		# A comment, used to store meta-information
		push(@rv, { 'comment' => $1,
			    'file' => $_[0],
			    'line' => $lnum,
			    'index' => scalar(@rv) });
		}
	elsif (/^([0-9\.]+):([0-9\.]+)/) {
		# A local/remote IP specification
		push(@rv, { 'local' => $1,
			    'remote' => $2,
			    'file' => $_[0],
			    'line' => $lnum,
			    'index' => scalar(@rv) });
		}
	elsif (/^([^# ]*)\s*([^#]*)/) {
		# A PPP options directive
		push(@rv, { 'name' => $1,
			    'value' => $2,
			    'file' => $_[0],
			    'line' => $lnum,
			    'index' => scalar(@rv) });
		}
	$lnum++;
	}
close(OPTS);
return @rv;
}

# find(name, &config)
sub find
{
local @rv = grep { lc($_->{'name'}) eq lc($_[0]) } @{$_[1]};
return wantarray ? @rv : $rv[0];
}

# save_ppp_option(&config, file, &old|name, &new)
sub save_ppp_option
{
local $ol = ref($_[2]) || !defined($_[2]) ? $_[2] : &find($_[2], $_[0]);
local $nw = $_[3];
local $lref = &read_file_lines($_[1]);
local $line;
if ($nw) {
	if ($nw->{'local'}) {
		$line = $nw->{'local'}.":".$nw->{'remote'};
		}
	elsif ($nw->{'comment'}) {
		$line = "# ".$nw->{'comment'};
		}
	else {
		$line = $nw->{'name'};
		$line .= " $nw->{'value'}" if ($nw->{'value'} ne "");
		}
	}
if ($ol && $nw) {
	$lref->[$ol->{'line'}] = $line;
	}
elsif ($ol) {
	splice(@$lref, $ol->{'line'}, 1);
	local $c;
	foreach $c (@{$_[0]}) {
		$c->{'line'}-- if ($c->{'line'} > $ol->{'line'});
		}
	}
elsif ($nw) {
	push(@$lref, $line);
	}
}

# list_connected()
# Returns a list of the names of tunnels that appear to be active. May include
# other ppp calls as well
sub list_connected
{
&foreign_require("proc", "proc-lib.pl");
local @rv;
foreach $p (&proc::list_processes()) {
	if ($p->{'args'} =~ /pppd\s.*call\s+(.*\S+)/) {
		push(@rv, [ $1, $p->{'pid'} ]);
		if ($1 eq $config{'tunnel'}) {
			$rv[$#rv]->[2] = $config{'iface'};
			}
		}
	}
return @rv;
}

# parse_comments(&tunnel)
sub parse_comments
{
foreach $c (@{$_[0]->{'opts'}}) {
	if ($c->{'comment'} =~ /Server IP: (\S+)/) {
		$_[0]->{'server'} = $1;
		$_[0]->{'server_c'} = $c;
		}
	elsif ($c->{'comment'} =~ /Route: (.*)/) {
		push(@{$_[0]->{'routes'}}, $1);
		push(@{$_[0]->{'routes_c'}}, $c);
		}
	}
}

@old_mppe = ( 'mppe-40', 'mppe-128', 'mppe-stateless' );
@new_mppe = ( [ 'mppe', 0, 'require-', 'no' ],
	      [ 'mppe-40', 1, 'require-', 'no' ],
	      [ 'mppe-128', 1, 'require-', 'no' ],
	      [ 'mppe-stateful', 0, '', 'no' ],
	    );

# mppe_options_form(&opts)
# Show a form for editing MPPE-related PPP options
sub mppe_options_form
{
# Get the PPPd version. Only those above 2.4.2 have built-in MPPE support
local $mppe_mode = &mppe_support();
print "<input type=hidden name=mppe_mode value='$mppe_mode'>\n";

local $opts = $_[0];
if ($mppe_mode) {
	# Show new MPPE options
	local $o;
	foreach $o (@new_mppe) {
		local $o0 = &find($o->[2].$o->[0], $opts);
		local $o1 = &find($o->[2].$o->[0], $opts);
		local $mode = $o0 ? 2 : $o1 ? 0 : 1;
		print "<tr> <td><b>",$text{'mppe_'.$o->[0]},"</b></td>\n";
		print "<td colspan=3>\n";
		printf "<input type=radio name=%s value=2 %s> %s\n",
			$o->[0], $mode == 2 ? "checked" : "", $text{'mppe_m2'};
		printf "<input type=radio name=%s value=1 %s> %s (%s)\n",
			$o->[0], $mode == 1 ? "checked" : "", $text{'default'},
			$o->[1] ? $text{'mppe_d1'} : $text{'mppe_d0'};
		printf "<input type=radio name=%s value=0 %s> %s\n",
			$o->[0], $mode == 0 ? "checked" : "", $text{'mppe_m0'};
		print "</td> </tr>\n";
		}
	local @anyold = grep { &find($_, $opts) } @old_mppe;
	if (@anyold) {
		print "<tr> <td colspan=4 align=center>",&text('mppe_old',
			"<tt>".join(" ", @anyold)."</tt>"),"</td> </tr>\n";
		}
	}
else {
	# Show old MPPE options
	$i = 0;
	foreach $o (@old_mppe) {
		print "<tr>\n" if ($i%2 == 0);
		local $v = &find($o, $opts);
		print "<td><b>",$text{'mppe_'.$o},"</b></td> <td>\n";
		printf "<input type=radio name=$o value=1 %s> %s\n",
			$v ? "checked" : "", $text{'yes'};
		printf "<input type=radio name=$o value=0 %s> %s</td>\n",
			$v ? "" : "checked", $text{'no'};
		print "</tr>\n" if ($i%2 == 1);
		$i++;
		}
	local @anynew = grep { &find($_, $opts) }
		( map { 'require-'.$_->[0] } @new_mppe ),
		( map { 'no'.$_->[0] } @new_mppe );
	if (@anynew) {
		print "<tr> <td colspan=4 align=center>",&text('mppe_new',
			"<tt>".join(" ", @anynew)."</tt>"),"</td> </tr>\n";
		}
	print "</tr>\n";
	}
}

# parse_mppe_options(&config, file)
sub parse_mppe_options
{
if ($in{'mppe_mode'}) {
	# Parse new-style options
	foreach my $opt (@new_mppe) {
		my $req = $opt->[2].$opt->[0];
		my $no = $opt->[3].$opt->[0];
		if ($in{$opt->[0]} == 2) {
			&save_ppp_option($_[0], $_[1], $req,
					 { 'name' => $req });
			&save_ppp_option($_[0], $_[1], $no, undef);
			}
		elsif ($in{$opt->[0]} == 1) {
			&save_ppp_option($_[0], $_[1], $req, undef);
			&save_ppp_option($_[0], $_[1], $no, undef);
			}
		else {
			&save_ppp_option($_[0], $_[1], $req, undef);
			&save_ppp_option($_[0], $_[1], $no,
					 { 'name' => $no });
			}
		}
	}
else {
	# Parse old-style options
	foreach my $o (@old_mppe) {
		&save_ppp_option($_[0], $_[1], $o,
				 $in{$o} ? { 'name' => $o } : undef);
		}
	}
}

# mppe_support()
# Returns 1 if the PPP daemon supports new-style MPPE options (version 2.4.2+,
# 0 if might only support the old options)
sub mppe_support
{
local $out = `pppd --help 2>&1`;
local $vers;
if ($out =~ /version\s+(\S+)/i) {
	$vers = $1;
	}
if ($vers =~ /^(\d+)/ && $1 > 2 ||
    $vers =~ /^(\d+)\.(\d+)/ && $1 == 2 && $2 > 4 ||
    $vers =~ /^(\d+)\.(\d+)\.(\d+)/ && $1 == 2 && $2 == 4 && $3 >= 2) {
	return 1;
	}
return 0;
}

# get_pppd_version(&out)
sub get_pppd_version
{
local $out = `pppd --help 2>&1`;
${$_[0]} = $out;
return $out =~ /version\s+(\S+)/i ? $1 : undef;
}

# connect_tunnel(&tunnel)
# Attempts to open some tunnel. Returns either :
# 1, iface-name, iface-address, iface-ptp
# 0, error-message
sub connect_tunnel
{
local $tunnel = $_[0];
&foreign_require("net", "net-lib.pl");

# Run the PPTP command, and wait for a new pppN interface to come up
local %sifaces = map { $_->{'fullname'}, $_->{'address'} } &get_ppp_ifaces();
local $start = time();
local $temp = &tempname();
&system_logged("modprobe ip_gre >/dev/null 2>&1");
&system_logged("$config{'pptp'} ".quotemeta($tunnel->{'server'})." call ".
	       quotemeta($tunnel->{'name'})." >$temp 2>&1 </dev/null &");
local $newiface;
LOOP: while(time() - $start < $config{'timeout'}) {
	sleep(1);
	local @nifaces = &get_ppp_ifaces();
	local $i;
	foreach $i (@nifaces) {
		if (!$sifaces{$i->{'fullname'}}) {
			$newiface = $i;
			last LOOP;
			}
		}
	}
local $tempout = `cat $temp`;
unlink($temp);

# Find out if we were connected, or if it failed
if ($newiface) {
	# It worked! Add the routes
	local (@rout, @rcmd);
	if (@{$tunnel->{'routes'}}) {
		local @routes = &net::list_routes();
		local ($defroute) = grep { $_->{'dest'} eq '0.0.0.0' } @routes;
		local $oldgw = $defroute->{'gateway'} if ($defroute);
		foreach $r (@{$tunnel->{'routes'}}) {
			$cmd = "route $r";
			$cmd =~ s/TUNNEL_DEV/$newiface->{'fullname'}/g;
			$cmd =~ s/DEF_GW/$oldgw/g;
			$cmd =~ s/GW/$newiface->{'ptp'}/g;
			push(@rcmd, $cmd);
			$out = &backquote_logged("$cmd 2>&1 </dev/null");
			push(@rout, $out);
			}
		}

	return (1, $newiface->{'fullname'}, $newiface->{'address'},
		   $newiface->{'ptp'}, \@rcmd, \@rout);
	}
else {
	# Must have timed out due to a failure
	&foreign_require("syslog", "syslog-lib.pl");
	local $sysconf = &syslog::get_config();
	local $c;
	local $logs;
	foreach $c (@$sysconf) {
		next if ($c->{'tag'} || !$c->{'file'} || !-f $c->{'file'});
		local @st = stat($c->{'file'});
		if ($st[9] > $start) {
			# Was modified since start .. but by ppp or pptp?
			local $tail = `tail -10 '$c->{'file'}'`;
			if ($tail =~ /ppp|pptp/) {
				$logs = $tail;
				last;
				}
			}
		}
	return (0, $tempout.$logs || "No logged error messages found");
	}
}

sub get_ppp_ifaces
{
return grep { $_->{'fullname'} =~ /^ppp(\d+)$/ &&
	      $_->{'up'} && $_->{'address'} } &net::active_interfaces();
}


1;

