# pserver-lib.pl

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

$cvs_path = &has_command($config{'cvs'});
$cvs_port = 2401;
$cvs_inet_name = "cvspserver";
$has_xinetd = &foreign_check("xinetd");
$has_inetd = &foreign_check("inetd");
$passwd_file = "$config{'cvsroot'}/CVSROOT/passwd";
$readers_file = "$config{'cvsroot'}/CVSROOT/readers";
$writers_file = "$config{'cvsroot'}/CVSROOT/writers";
$cvs_config_file = "$config{'cvsroot'}/CVSROOT/config";

@features = ('passwd', 'access', 'config', 'cvsweb');
%access = &get_module_acl();
%featureprog = ( 'passwd' => 'list_passwd.cgi',
		 'access' => 'edit_access.cgi',
		 'config' => 'edit_config.cgi',
		 'cvsweb' => 'cvsweb.cgi' );

# check_inetd()
# Find out if cvs is being run from inetd or xinetd
sub check_inetd
{
if ($has_xinetd) {
	# Find an xinetd service on the CVS port, with the CVS command, or
	# with the CVS name
	&foreign_require("xinetd", "xinetd-lib.pl");
	local @xic = &xinetd::get_xinetd_config();
	local $x;
	foreach $x (@xic) {
		next if ($x->{'name'} ne 'service');
		local $q = $x->{'quick'};
		if ($q->{'server'}->[0] eq $cvs_path ||
		    $q->{'server'}->[0] eq $config{'cvs'} ||
		    $port == $cvs_port ||
		    $x->{'value'} eq $cvs_inet_name) {
			# Found the entry
			return { 'type' => 'xinetd',
				 'user' => $q->{'user'}->[0],
				 'command' => $q->{'server'}->[0],
				 'args' => $q->{'server'}->[0]." ".
					   $q->{'server_args'}->[0],
				 'active' => $q->{'disable'}->[0] ne 'yes',
				 'xinetd' => $x };
			}
		}
	}
if ($has_inetd) {
	# Find an inetd service on the CVS port, with the CVS command, or
	# with the CVS name
	local (%portmap, $s, $a, $i);
	&foreign_require("inetd", "inetd-lib.pl");
	foreach $s (&inetd::list_services()) {
		$portmap{$s->[1]} = $s;
		foreach $a (split(/\s+/, $s->[4])) {
			$portmap{$a} = $s;
			}
		}
	foreach $i (&inetd::list_inets()) {
		if ($i->[8] eq $cvs_path || $i->[8] eq $config{'cvs'} ||
		    $portmap{$i->[3]}->[2] == $cvs_port ||
		    $i->[3] eq $cvs_inet_name) {
			# Found the entry
			return { 'type' => 'inetd',
				 'user' => $i->[7],
				 'command' => $i->[8],
				 'args' => $i->[9],
				 'active' => $i->[1],
				 'inetd' => $i };
			}
		}
	}
return undef;
}

# list_passwords()
# List all CVS users
sub list_passwords
{
local @rv;
local $lnum = 0;
open(PASSWD, $passwd_file);
while(<PASSWD>) {
	s/\r|\n//g;
	s/#.*$//;
	local @p = split(/:/, $_);
	if (@p) {
		push(@rv, { 'user' => $p[0],
			    'pass' => $p[1],
			    'unix' => $p[2],
			    'line' => $lnum,
			    'index' => scalar(@rv) });
		}
	$lnum++;
	}
close(PASSWD);
return @rv;
}

sub create_password
{
local $lref = &read_file_lines($passwd_file);
push(@$lref, join(":", $_[0]->{'user'}, $_[0]->{'pass'}, $_[0]->{'unix'}));
&flush_file_lines();
}

sub modify_password
{
local $lref = &read_file_lines($passwd_file);
$lref->[$_[0]->{'line'}] =
	join(":", $_[0]->{'user'}, $_[0]->{'pass'}, $_[0]->{'unix'});
&flush_file_lines();
}

sub delete_password
{
local $lref = &read_file_lines($passwd_file);
splice(@$lref, $_[0]->{'line'}, 1);
&flush_file_lines();
}

# get_cvs_config()
# Returns a list of values from the CVSROOT/config file
sub get_cvs_config
{
local @rv;
local $lnum = 0;
open(CONFIG, $cvs_config_file);
while(<CONFIG>) {
	s/\s+$//;
	s/^\s*#.*$//;
	if (/^\s*([^\s=]+)\s*=\s*(.*)/) {
		push(@rv, { 'name' => $1,
			    'value' => $2,
			    'line' => $lnum,
			    'index' => scalar(@rc) } );
		}
	$lnum++;
	}
close(CONFIG);
return @rv;
}

# find(name, &config)
sub find
{
local ($c, @rv);
foreach $c (@{$_[1]}) {
	push(@rv, $c) if (lc($c->{'name'}) eq lc($_[0]));
	}
return wantarray ? @rv : $rv[0];
}

# save_cvs_config(&config, name, value, [default])
sub save_cvs_config
{
local $lref = &read_file_lines($cvs_config_file);
local $old = &find($_[1], $_[0]);
if ($old && $_[2]) {
	# Replacing an existing config line
	$lref->[$old->{'line'}] = "$_[1]=$_[2]";
	}
elsif ($old) {
	# Deleting a config line (unless it already exists with the default)
	if (!$_[3] || $old->{'value'} ne $_[3]) {
		splice(@$lref, $old->{'line'}, 1);
		local $c;
		foreach $c (@{$_[0]}) {
			$c->{'line'}-- if ($c->{'line'} > $old->{'line'});
			}
		}
	}
elsif ($_[2]) {
	# Adding a config line
	push(@$lref, "$_[1]=$_[2]");
	}
}

# get_cvs_version(&out)
# Returns the cvs command version number, or undef
sub get_cvs_version
{
local $out = `$config{'cvs'} -v`;
${$_[0]} = $out;
if ($out =~ /CVS[^0-9\.]*([0-9\.]+)/) {
	return $1;
	}
else {
	return undef;
	}
}

@hist_chars = ( "F", "O", "E", "T", "C", "G", "U", "W", "A", "M", "R" );

1;

