# Functions for parsing and updating the LDAP config file

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

@base_types = ("passwd", "shadow", "group", "hosts", "networks", "netmasks",
	       "services", "protocols", "aliases", "netgroup");

# get_ldap_config_file()
# Returns the first config file that exists
sub get_ldap_config_file
{
my @confs = split(/\s+/, $config{'auth_ldap'});
foreach my $c (@$confs) {
	return $c if (-e $c);
	}
return $confs[0];
}

# get_config()
# Parses the NSS LDAP config file into a list of names and values
sub get_config
{
local $file = $_[0] || &get_ldap_config_file();
if (!scalar(@get_config_cache)) {
	local $lnum = 0;
	@get_config_cache = ( );
	&open_readfile(CONF, $file);
	while(<CONF>) {
		s/\r|\n//g;
		if (/^(#?)(\S+)\s*(.*)/) {
			my $dir = { 'name' => lc($2),
				    'value' => $3,
				    'enabled' => !$1,
				    'line' => $lnum,
				    'file' => $file };
			$dir->{'value'} =~ s/\s+#.*$//;   # Trailing comments
			push(@get_config_cache, $dir);
			}
		$lnum++;
		}
	close(CONF);
	}
return \@get_config_cache;
}

# find(name, &conf, disabled-mode(0=enabled, 1=disabled, 2=both))
# Returns the directive objects with some name
sub find
{
local ($name, $conf, $dis) = @_;
local @rv = grep { $_->{'name'} eq $name } @$conf;
if ($dis == 0) {
	# Enabled only
	@rv = grep { $_->{'enabled'} } @rv;
	}
elsif ($dis == 1) {
	# Disabled only
	@rv = grep { !$_->{'enabled'} } @rv;
	}
return wantarray ? @rv : $rv[0];
}

# find_value(name, &conf, [disabled])
# Finds the value or values of a directive
sub find_value
{
local ($name, $conf, $dis) = @_;
local @rv = map { $_->{'value'} } &find($name, $conf, $dis);
return wantarray ? @rv : $rv[0];
}

# find_svalue(name, &conf, [disabled])
# Like find_value, but only returns a single value
sub find_svalue
{
local $rv = &find_value(@_);
return $rv;
}

# save_directive(&conf, name, [value|&values])
# Update one or more directives with some name
sub save_directive
{
local ($conf, $name, $valuez) = @_;
local @values = ref($valuez) ? @$valuez : ( $valuez );
local @old = &find($name, $conf);
local @oldcmt = &find($name, $conf, 1);
local $deffile = &get_ldap_config_file();

for(my $i=0; $i<@old || $i<@values; $i++) {
	local $old = $old[$i];
	local $oldcmt = $oldcmt[$i];
	local $value = $values[$i];
	local $lref = &read_file_lines($old ? $old->{'file'} :
				       $oldcmt ? $oldcmt->{'file'} :
						 $deffile);
	if (defined($value) && $old) {
		# Just update value
		$old->{'value'} = $value;
		$lref->[$old->{'line'}] = "$name $value";
		}
	elsif (defined($value) && $oldcmt) {
		# Add value after commented version
		splice(@$lref, $oldcmt->{'line'}+1, 0, "$name $value");
		&renumber($conf, $oldcmt->{'line'}+1, $oldcmt->{'file'}, 1);
		push(@$conf, { 'name' => $name,
			       'value' => $value,
			       'enabled' => 1,
			       'line' => $oldcmt->{'line'}+1,
			       'file' => $oldcmt->{'file'} });
		}
	elsif (!defined($value) && $old) {
		# Delete current value
		splice(@$lref, $old->{'line'}, 1);
		&renumber($conf, $old->{'line'}, $old->{'file'}, -1);
		@$conf = grep { $_ ne $old } @$conf;
		}
	elsif ($value) {
		# Add value at end of file
		push(@$conf, { 'name' => $name,
			       'value' => $value,
			       'enabled' => 1,
			       'line' => scalar(@$lref),
			       'file' => $deffile });
		push(@$lref, "$name $value");
		}
	}
}

sub renumber
{
local ($conf, $line, $file, $offset) = @_;
foreach my $c (@$conf) {
	if ($c->{'line'} >= $line && $c->{'file'} eq $file) {
		$c->{'line'} += $offset;
		}
	}
}

# get_rootbinddn_secret()
# Returns the password used when the root user connects to the LDAP server
sub get_rootbinddn_secret
{
local @secrets = split(/\t+/, $config{'secret'});
&open_readfile(SECRET, $secrets[0]) || return undef;
local $secret = <SECRET>;
close(SECRET);
$secret =~ s/\r|\n//g;
return $secret;
}

# save_rootbinddn_secret(secret)
# Saves the password used when the root user connects to the LDAP server
sub save_rootbinddn_secret
{
local @secrets = split(/\t+/, $config{'secret'});
if (defined($_[0])) {
	foreach my $secret (@secrets) {
		&open_tempfile(SECRET, ">$secret");
		&print_tempfile(SECRET, $_[0],"\n");
		&close_tempfile(SECRET);
		&set_ownership_permissions(0, 0, 0600, $secret);
		}
	}
else {
	&unlink_file(@secrets);
	}
}

# ldap_connect(return-error, [&host])
# Connect to the LDAP server and return a handle to the Net::LDAP object
sub ldap_connect
{
# Load the LDAP module
eval "use Net::LDAP";
if ($@) {
	local $err = &text('ldap_emodule', "<tt>Net::LDAP</tt>",
		   "../cpan/download.cgi?source=3&".
		   "cpan=Convert::ASN1%20Net::LDAP&mode=2&".
		   "return=../$module_name/&".
		   "returndesc=".&urlize($module_info{'desc'}));
	if ($_[0]) { return $err; }
	else { &error($err); }
	}
local $err = &generic_ldap_connect($config{'ldap_hosts'}, $config{'ldap_port'},
			     $config{'ldap_tls'}, $config{'ldap_user'},
			     $config{'ldap_pass'});
if (ref($err)) { return $err; }		# Worked
elsif ($_[0]) { return $err; }		# Caller asked for error return
else { &error($err); }			# Caller asked for error() call
}

# generic_ldap_connect([host], [port], [ssl], [login], [password])
# A generic function for connecting to an LDAP server. Uses the system's
# LDAP client config file if any parameters are missing. Returns the LDAP
# handle on success or an error message on failure.
sub generic_ldap_connect
{
local ($ldap_hosts, $ldap_port, $ldap_ssl, $ldap_user, $ldap_pass) = @_;

# Check for perl module and config file
eval "use Net::LDAP";
if ($@) {
	return &text('ldap_emodule2', "<tt>Net::LDAP</tt>");
	}
my $deffile = &get_ldap_config_file();
if (!-r $deffile) {
	$ldap_hosts && $ldap_user ||
		return &text('ldap_econf', "<tt>$deffile</tt>");
	}

# Get the host and port
local $conf = &get_config();
local $uri = &find_svalue("uri", $conf);
local ($ldap, $use_ssl, $err);
local $ssl = &find_svalue("ssl", $conf);
local $cafile = &find_svalue("tls_cacertfile", $conf);
local $certfile = &find_svalue("tls_cert", $conf);
local $keyfile = &find_svalue("tls_key", $conf);
local $ciphers = &find_svalue("tls_ciphers", $conf);
local $host;
if ($ldap_hosts) {
	# Using hosts from parameter
	local @hosts = split(/[ \t,]+/, $ldap_hosts);
	if ($ldap_ssl ne '') {
		$use_ssl = $ldap_ssl;
		}
	else {
		$use_ssl = $ssl eq 'yes' ? 1 :
			   $ssl eq 'start_tls' ? 2 : 0;
		}
	local $port = $ldap_port ||
		      &find_svalue("port", $conf) ||
		      ($use_ssl == 1 ? 636 : 389);
	foreach my $h (@hosts) {
		eval {
			$ldap = Net::LDAP->new($h, port => $port,
				scheme => $use_ssl == 1 ? 'ldaps' : 'ldap',
				inet6 => &should_use_inet6($h));
			};
		if ($@) {
			$err = &text('ldap_econn2',
				     "<tt>$host</tt>", "<tt>$port</tt>",
				     &html_escape($@));
			}
		elsif (!$ldap) {
			$err = &text('ldap_econn',
				     "<tt>$host</tt>", "<tt>$port</tt>");
			}
		else {
			$host = $h;
			$err = undef;
			last;
			}
		}
	}
elsif ($uri) {
	# Using uri directive
	foreach my $u (split(/\s+/, $uri)) {
		if ($u =~ /^(ldap|ldaps|ldapi):\/\/([a-z0-9\_\-\.]+)(:(\d+))?/i) {
			($proto, $host, $port) = ($1, $2, $4);
			if (!$port && $proto eq "ldap") {
				$port = 389;
				}
			elsif (!$port && $proto eq "ldaps") {
				$port = 636;
				}
			$ldap = Net::LDAP->new($host, port => $port,
				       scheme => $proto,
				       inet6 => &should_use_inet6($host));
			if (!$ldap) {
				$err = &text('ldap_econn',
					     "<tt>$host</tt>","<tt>$port</tt>");
				}
			else {
				$err = undef;
				$use_ssl = $proto eq "ldaps" ? 1 :
					   $ssl eq 'start_tls' ? 2 : 0;
				last;
				}
			}
		}
	if (!$ldap && !$err) {
		$err = &text('ldap_eparse', $uri);
		}
	}
else {
	# Using host and port directives
	$use_ssl = $ssl eq 'yes' ? 1 :
		   $ssl eq 'start_tls' ? 2 : 0;
	local @hosts = split(/[ ,]+/, &find_svalue("host", $conf));
	local $port = &find_svalue("port", $conf) ||
		      ($use_ssl == 1 ? 636 : 389);
	@hosts = ( "localhost" ) if (!@hosts);

	foreach my $h (@hosts) {
		$ldap = Net::LDAP->new($h, port => $port,
			       scheme => $use_ssl == 1 ? 'ldaps' : 'ldap',
			       inet6 => &should_use_inet6($h));
		if (!$ldap) {
			$err = &text('ldap_econn',
				     "<tt>$host</tt>", "<tt>$port</tt>");
			}
		else {
			$host = $h;
			$err = undef;
			last;
			}
		}
	}

# Start TLS if configured
if ($use_ssl == 2 && !$err) {
	local $mesg;
	if ($certfile) {
		# Use cert to connect
		eval { $mesg = $ldap->start_tls(
					cafile     => $cafile,
                                        clientcert => $certfile,
                                        clientkey  => $keyfile,
                                        ciphers    => $ciphers
					); };

		}
	else {
		eval { $mesg = $ldap->start_tls(); };
		}
	if ($@ || !$mesg || $mesg->code) {
		$err = &text('ldap_etls', $@ ? $@ : $mesg ? $mesg->error :
					  "Unknown error");
		}
	}

if ($err) {
	return $err;
	}

local ($dn, $password);
local $rootbinddn = &find_svalue("rootpwmoddn", $conf) ||
		    &find_svalue("rootbinddn", $conf);
if ($ldap_user) {
	# Use login from config
	$dn = $ldap_user;
	$password = $ldap_pass;
	}
elsif ($rootbinddn) {
	# Use the root login if we have one
	$dn = $rootbinddn;
	$password = &find_svalue("rootpwmodpw", $conf) ||
		    &get_rootbinddn_secret();
	}
else {
	# Use the normal login
	$dn = &find_svalue("binddn", $conf);
	$password = &find_svalue("bindpw", $conf);
	}
local $mesg;
if ($password) {
	$mesg = $ldap->bind(dn => $dn, password => $password);
	}
else {
	$mesg = $ldap->bind(dn => $dn, anonymous => 1);
	}
if (!$mesg || $mesg->code) {
	local $err = &text('ldap_elogin', "<tt>$host</tt>",
		     	   $dn || $text{'ldap_anon'},
			   $mesg ? $mesg->error : "Unknown error");
	if ($_[0]) { return $err; }
	else { &error($err); }
	}
return $ldap;
}

# should_use_inet6(host)
# Returns 1 if some host has a v6 address but not v4
sub should_use_inet6
{
local ($host) = @_;
return !&to_ipaddress($host) && &to_ip6address($host);
}

# base_chooser_button(field, node, form)
# Returns HTML for a popup LDAP base chooser button
sub base_chooser_button
{
local ($field, $node, $form) = @_;
$form ||= 0;
local $w = 500;
local $h = 500;
if ($gconfig{'db_sizeusers'}) {
	($w, $h) = split(/x/, $gconfig{'db_sizeusers'});
	}
return "<input type=button onClick='ifield = document.forms[$form].$field; chooser = window.open(\"popup_browser.cgi?node=$node&base=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=$w,height=$h\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\">\n";
}

# get_ldap_host()
# Returns the hostname probably used for connecting
sub get_ldap_host
{
local @hosts;
if ($config{'ldap_hosts'}) {
	@hosts = split(/\s+/, $config{'ldap_hosts'});
	}
elsif (!-r &get_ldap_config_file()) {
	@hosts = ( );
	}
else {
	local $conf = &get_config();
	local $uri = &find_svalue("uri", $conf);
	if ($uri) {
		foreach my $u (split(/\s+/, $uri)) {
			if ($u =~ /^(ldap|ldaps|ldapi):\/\/([a-z0-9\_\-\.]+)(:(\d+))?/) {
				push(@hosts, $2);
				}
			}
		}
	else {
		@hosts = split(/[ ,]+/, &find_svalue("host", $conf));
		}
	if (!@hosts) {
		@hosts = ( "localhost" );
		}
	}
return wantarray ? @hosts : $hosts[0];
}

# fix_ldap_authconfig()
# If the systme has a /etc/sysconfig/authconfig file, enable LDAP in it.
sub fix_ldap_authconfig
{
my $afile = "/etc/sysconfig/authconfig";
return 0 if (!-r $afile);
&lock_file($afile);
my %auth;
&read_env_file($afile, \%auth);
if ($auth{'USELDAP'} =~ /no/i) {
	$auth{'USELDAP'} = 'yes';
	$changed++;
	}
if ($auth{'USELDAPAUTH'} =~ /no/i) {
	$auth{'USELDAPAUTH'} = 'yes';
	$changed++;
	}
if ($changed) {
	&write_env_file($afile, \%auth);
	}
&unlock_file($afile);
}

# get_ldap_client()
# Returns either "nss" or "nslcd" depending on the LDAP client being used
sub get_ldap_client
{
return $config{'auth_ldap'} =~ /nslcd/ ? 'nslcd' : 'nss';
}

1;

