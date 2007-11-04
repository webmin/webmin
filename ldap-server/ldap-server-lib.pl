# Functions for configuring and talking to an LDAP server
# XXX icon

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';

eval "use Net::LDAP";
if ($@) { $net_ldap_error = $@; }

# connect_ldap_db()
# Attempts to connect to an LDAP server. Returns a handle on success or an
# error message string on failure.
sub connect_ldap_db
{
return $connect_ldap_db_cache if (defined($connect_ldap_db_cache));

# Do we have the module?
if ($net_ldap_error) {
	return &text('connect_emod', "<tt>Net::LDAP</tt>",
		     "<pre>".&html_escape($net_ldap_error)."</pre>");
	}

# Work out server name, login and TLS mode
local ($server, $port, $user, $pass, $ssl) = @_;
if ($config{'server'}) {
	# Remote box .. everything must be set
	$server = $config{'server'};
	gethostbyname($server) || return &text('connect_eserver',
					       "<tt>$server</tt>");
	$port = $config{'port'} || 389;
	$user = $config{'user'};
	$user || return $text{'connect_euser'};
	$pass = $config{'pass'};
	$pass || return $text{'connect_epass'};
	}
else {
	# Get from slapd.conf
	-r $config{'config_file'} || return &text('connect_efile',
					"<tt>$config{'config_file'}</tt>");
	local $conf = &get_config();
	$server = "127.0.0.1";
	$port = $config{'port'} || &find_value("port", $conf) || 389;
	$user = $config{'user'} || &find_value("rootdn", $conf);
	$user || return $text{'connect_euser2'};
	$pass = $config{'pass'} || &find_value("rootpw", $conf);
	$pass || return $text{'connect_epass2'};
	$pass =~ /^\{/ && return $text{'connect_epass3'};
	}
$ssl = $config{'ssl'};

# Try to connect
local @ssls = $ssl eq "" ? ( 1, 0 ) : ( $ssl );
local $ldap;
foreach $ssl (@ssls) {
	$ldap = Net::LDAP->new($server, port => $port);
	if (!$ldap) {
		return &text('connect_eldap', "<tt>$server</tt>", $port);
		}
	if ($ssl) {
		# Switch to TLS mode
		local $mesg = $ldap->start_tls();
		if (!$mesg || $mesg->code) {
			next if (@ssls);  # Try non-SSL
			}
		else {
			return &text('connect_essl', "<tt>$server</tt>",
				     $mesg ? $mesg->code : "Unknown error");
			}
		}
	}
$ldap || return "This can't happen!";

# Login to server
local $mesg = $ldap->bind(dn => $user, password => $pass);
if (!$mesg || $mesg->code) {
	return &text('connect_elogin', "<tt>$server</tt>", "<tt>$user</tt>",
		     $mesg ? $mesg->error : "Unknown error");
	}

$connect_ldap_db = $ldap;
return $ldap;
}

# get_config([file])
# Returns an array ref of LDAP server configuration settings
sub get_config
{
local $file = $_[0] || $config{'config_file'};
if (defined($get_config_cache{$file})) {
	return $get_config_cache{$file};
	}
local @rv;
local $lnum = 0;
open(CONF, $file);
while(<CONF>) {
	s/\r|\n//g;
	s/^\s*#.*$//;
	if (/^(\S+)\s*(.*)$/) {
		# Found a directive
		local $dir = { 'name' => $1,
			       'line' => $lnum,
			       'file' => $file };
		local $value = $2;
		$dir->{'values'} = &split_quoted_string($value);
		push(@rv, $dir);
		}
	$lnum++;
	}
close(CONF);
$get_config_cache{$file} = \@rv;
return \@rv;
}

sub find
{
local ($name, $conf) = @_;
local @rv = grep { lc($_->{'name'}) eq lc($name) } @$conf;
return wantarray ? @rv : $rv[0];
}

sub find_value
{
local ($name, $conf) = @_;
local @rv = map { $_->{'values'}->[0] } &find(@_);
return wantarray ? @rv : $rv[0];
}

sub start_ldap_server
{
}

sub stop_ldap_server
{
}

sub apply_configuration
{
}

sub is_ldap_server_running
{
}

sub get_ldap_server_pid
{
}

1;

