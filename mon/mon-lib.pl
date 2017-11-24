# mon-lib.pl
# Common functions for mon 

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

$mon_config_file = "$config{'cfbasedir'}/mon.cf";
$under = { '' => [ 'authtype', 'hostgroup', 'watch', 'use', 'period',
		   'serverbind', 'trapbind' ],
	   'watch' => [ 'service' ],
	   'service' => [ 'description', 'interval', 'monitor', 'period',
			  'depend', 'allow_empty_group', 'traptimeout',
			  'trapduration', 'randskew', 'dep_behavior',
			  'dep_behaviour', 'exclude_hosts', 'exclude_period',
			  'failure_interval', 'redistribute' ],
	   'period' => [ 'alert', 'upalert', 'alertevery', 'alertafter',
			 'numalerts', 'comp_alerts', 'startupalert',
			 'upalertafter', 'no_comp_alerts' ]
	 };

# get_mon_config()
# Parses the mon config file into a heirachical structure
sub get_mon_config
{
if (@get_mon_config_cache) {
	return \@get_mon_config_cache;
	}
local @rv;
local $cv = \@rv;
local ($last_indent, $parent);
local $lnum = 0;
open(CONF, $mon_config_file);
while(<CONF>) {
	local $slnum = $lnum;
	s/\s+$//;
	s/#.*$//g;
	while(s/\\$//) {
		local $nl = <CONF>;
		$nl =~ s/\s+$//;
		$nl =~ s/^\s+//;
		$_ .= $nl;
		$lnum++;
		}
	if (/^(\S+)\s*=\s*(.*)$/) {
		# Global directive
		local $str = { 'name' => $1,
			       'values' => [ split(/\s+/, $2) ],
			       'value' => $2,
			       'global' => 1,
			       'index' => scalar(@rv),
			       'line' => $slnum,
			       'eline' => $lnum };
		push(@rv, $str);
		}
	elsif (/^(\s*)(\S+)\s*(.*)$/) {
		# Normal directive, possibly in a heirachy
		local $str = { 'name' => $2,
			       'values' => [ split(/\s+/, $3) ],
			       'value' => $3,
			       'members' => [ { 'dummy' => 1,
						'line' => $lnum,
						'eline' => $lnum } ],
			       'indent' => $1,
			       'line' => $slnum,
			       'eline' => $lnum };

		# Check if under the previous directive
		local $found;
		if (@$cv > 0) {
			local $ld = $cv->[@$cv-1];
			local $pu = $under->{$ld->{'name'}};
			foreach $u (@$pu) {
				$found++ if ($u eq $str->{'name'});
				}
			if ($found) {
				# It is .. so just update the parent
				$parent = $ld;
				$cv = $ld ? $ld->{'members'} : \@rv;
				}
			}

		if (!$found) {
			# Check if under a parent
			local $pp = $parent;
			while(1) {
				local $pu = $under->{$pp ? $pp->{'name'} : ""};
				foreach $u (@$pu) {
					$found++ if ($u eq $str->{'name'});
					}
				if ($found) {
					# Under some ancestor .. make that
					# the current parent
					$parent = $pp;
					$cv = $pp ? $pp->{'members'} : \@rv;
					last;
					}
				else {
					last if (!$pp);
					$pp = $pp->{'parent'};
					}
				}

			if (!$found) {
				# Check if a hostname under a previous hostgroup
				if (@$cv &&
				    $cv->[$#cv]->{'name'} eq 'hostgroup') {
					push(@{$cv->[$#cv]->{'values'}},
					     $str->{'name'});
					$cv->[$#cv]->{'eline'} = $lnum;
					goto nextline;
					}
				}
			&error("Unknown directive $str->{'name'}")
				if (!$found);
			}
	
		$str->{'index'} = scalar(@$cv);
		$str->{'parent'} = $parent;
		push(@$cv, $str);

		# Set parent end lines
		local $pp = $parent;
		do {
			$pp->{'eline'} = $lnum;
			$pp = $pp->{'parent'};
			} while($pp);
		}

	nextline:
	$lnum++;
	}
close(CONF);
@get_mon_config_cache = @rv;
return \@get_mon_config_cache;
}

# find_value(name, &config)
sub find_value
{
foreach $c (@{$_[1]}) {
	if ($c->{'name'} eq $_[0]) {
		return wantarray ? @{$c->{'values'}} : $c->{'values'}->[0];
		}
	}
return wantarray ? ( ) : undef;
}

# find(name, &config)
sub find
{
local @rv;
foreach $c (@{$_[1]}) {
	if ($c->{'name'} eq $_[0]) {
		push(@rv, $c);
		}
	}
return wantarray ? @rv : $rv[0];
}

# save_directive(&config, [&old|undef], [&new|undef])
sub save_directive
{
local $lref = &read_file_lines($mon_config_file);
local @same = &find($_[2]->{'name'}, $_[0]) if ($_[2]);
local $idx = &indexof($_[1], @{$_[0]}) if ($_[1]);
local $olen = $_[1]->{'eline'} - $_[1]->{'line'} + 1 if ($_[1]);
local $conf = &get_mon_config();
local @dirs = &directive_lines($_[2], $_[2]->{'indent'}) if ($_[2]);
if ($_[1] && $_[2]) {
	# Replace the old directive
	splice(@$lref, $_[1]->{'line'}, $_[1]->{'eline'} - $_[1]->{'line'} + 1,
	       @dirs);
	$_[0]->[$idx] = $_[2];
	&renumber($conf, $_[1]->{'line'}, @dirs - $olen);
	$_[2]->{'line'} = $_[1]->{'line'};
	$_[2]->{'eline'} = $_[2]->{'line'} + @dirs - 1;
	}
elsif ($_[1] && !$_[2]) {
	# Remove the old directive
	splice(@$lref, $_[1]->{'line'}, $_[1]->{'eline'} - $_[1]->{'line'} + 1);
	splice(@{$_[0]}, $idx, 1);
	&renumber($conf, $_[1]->{'line'}, -$olen);
	}
elsif (@same) {
	# Add after last directive of same type
	splice(@$lref, $same[@same-1]->{'eline'}+1, 0, @dirs);
	splice(@{$_[0]}, $idx+1, 0, $_[2]);
	&renumber($conf, $same[@same-1]->{'eline'}+1, scalar(@dirs));
	$_[2]->{'line'} = $same[@same-1]->{'eline'}+1;
	$_[2]->{'eline'} = $_[2]->{'line'} + @dirs - 1;
	}
else {
	# Add after last directive in config
	local $ld = $_[0]->[@{$_[0]}-1];
	splice(@$lref, $ld->{'eline'} + 1, 0, @dirs);
	push(@{$_[0]}, $_[2]);
	&renumber($conf, $ld->{'eline'} + 1, scalar(@dirs));
	$_[2]->{'line'} = $ld->{'eline'} + 1;
	$_[2]->{'eline'} = $ld->{'eline'} + @dirs - 1;
	}
}

# renumber(&config, position, offset)
sub renumber
{
foreach $c (@{$_[0]}) {
	$c->{'line'} += $_[2] if ($c->{'line'} >= $_[1]);
	$c->{'eline'} += $_[2] if ($c->{'eline'} >= $_[1]);
	&renumber($c->{'members'}, $_[1], $_[2]);
	}
}

# directive_lines(&directive, [indent])
sub directive_lines
{
local @rv;
@rv = ( $_[1].join(" ", $_[0]->{'name'}, $_[0]->{'global'} ? ( "=" ) : ( ),
		        @{$_[0]->{'values'}}) );
foreach $m (@{$_[0]->{'members'}}) {
	push(@rv, &directive_lines($m, "$_[1]    ")) if (!$m->{'dummy'});
	}
return @rv;
}

# list_monitors()
# Returns a list of all monitors
sub list_monitors
{
local $conf = &get_mon_config();
local $mondir = &find_value("mondir", $conf);
local @rv;
foreach my $dir (split(/:/, $mondir)) {
	opendir(DIR, $dir);
	foreach my $f (readdir(DIR)) {
		push(@rv, $f) if ($f =~ /\.monitor$/);
		}
	closedir(DIR);
	}
return @rv;
}

# list_alerts()
# Returns a list of all alerts
sub list_alerts
{
local $conf = &get_mon_config();
local $mondir = &find_value("alertdir", $conf);
local @rv;
foreach my $dir (split(/:/, $mondir)) {
	opendir(DIR, $dir);
	foreach $f (readdir(DIR)) {
		push(@rv, $f) if ($f =~ /\.alert$/ || $f =~ /^alert\./);
		}
	closedir(DIR);
	}
return @rv;
}

# mon_users_file()
# Returns the file in which MON users are stored
sub mon_users_file
{
local $conf = &get_mon_config();
local $uf = &find_value("userfile", $conf);
$uf = "monusers.cf" if (!$uf);
if ($uf =~ /^\//) {
	return $uf;
	}
else {
	local $bd = &find_value("cfbasedir", $conf);
	$bd = $config{'cfbasedir'} if (!$bd);
	return "$bd/$uf";
	}
}

# list_users()
sub list_users
{
local(@rv, $lnum = 0);
open(USERS, &mon_users_file());
while(<USERS>) {
	s/\r|\n//g;
	s/#.*//;
	if (/^([^:]+):(\S+)/) {
		push(@rv, { 'user' => $1, 'pass' => $2, 'line' => $lnum });
		}
	$lnum++;
	}
close(USERS);
return @rv;
}

# create_user(&user)
sub create_user
{
local $lref = &read_file_lines(&mon_users_file());
push(@$lref, $_[0]->{'user'}.":".$_[0]->{'pass'});
&flush_file_lines(&mon_users_file());
}

# modify_user(&user)
sub modify_user
{
local $lref = &read_file_lines(&mon_users_file());
$lref->[$_[0]->{'line'}] = $_[0]->{'user'}.":".$_[0]->{'pass'};
&flush_file_lines(&mon_users_file());
}

# delete_user(&user)
sub delete_user
{
local $lref = &read_file_lines(&mon_users_file());
splice(@$lref, $_[0]->{'line'}, 1);
&flush_file_lines(&mon_users_file());
}

# mon_auth_file()
sub mon_auth_file
{
local $conf = &get_mon_config();
local $af = &find_value("authfile", $conf);
$af = "auth.cf" if (!$af);
if ($af =~ /^\//) {
	return $af;
	}
else {
	local $bd = &find_value("cfbasedir", $conf);
	return "$bd/$af";
	}
}

sub list_auth_types
{
return ('list', 'servertime', 'reset', 'loadstate', 'savestate',
	'term', 'stop', 'start', 'set', 'get', 'dump', 'disable',
	'enable', 'test', 'ack', 'reload', 'clear');
}

# day_input(name, value)
sub day_input
{
local @days = ( 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun' );
local $rv = "<select name=$_[0]>\n";
foreach $d (@days) {
	$rv .= sprintf "<option %s>%s</option>\n",
		lc($d) eq lc($_[1]) ? "selected" : "", $d;
	}
$rv .= "</select>\n";
return $rv;
}

# interval_input(name, value)
sub interval_input
{
local ($int, $units, $rv);
if ($_[1] =~ /^([\d\.]+)(\S)$/) {
	$int = $1; $units = $2;
	}
$rv = "<input name=$_[0] size=6 value='$int'>\n";
$rv .= "<select name=$_[0]_u>\n";
foreach $u ('s', 'm', 'h', 'd') {
	$rv .= sprintf "<option value=%s %s>%s</option>\n",
		$u, $units eq $u ? "selected" : "", $text{"service_units_$u"};
	}
$rv .= "</select>\n";
return $rv;
}

# restart_mon()
# Re-start the MON process, returning undef on success or an error message
# on failure
sub restart_mon
{
if ($config{'restart_cmd'}) {
        local $out =
		&backquote_logged("$config{'restart_cmd'} 2>&1 </dev/null");
        return "<tt>$out</tt>" if ($?);
        }
else {
	local $pid = &check_pid_file($config{'pid_file'});
	if ($pid) {
                kill('HUP', $pid);
		return undef;
                }
        else {
                return $text{'restart_epid'};
                }
        }
}

1;
