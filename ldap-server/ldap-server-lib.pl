# Functions for configuring and talking to an LDAP server

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();

eval "use Net::LDAP";
if ($@) { $net_ldap_error = $@; }

@search_attrs = ( 'objectClass', 'cn', 'dn', 'uid' );
@acl_dn_styles = ( 'regex', 'base', 'one', 'subtree', 'children' );
@acl_access_levels = ( 'none', 'auth', 'compare', 'search', 'read', 'write' );

# connect_ldap_db()
# Attempts to connect to an LDAP server. Returns a handle on success or an
# error message string on failure.
sub connect_ldap_db
{
return $connect_ldap_db_cache if (defined($connect_ldap_db_cache));

# Do we have the module?
if ($net_ldap_error) {
	local $msg = &text('connect_emod', "<tt>Net::LDAP</tt>",
		     "<pre>".&html_escape($net_ldap_error)."</pre>");
	if (foreign_available("cpan")) {
		$msg .= "<p>\n";
		$msg .= &text('connect_cpan', "Net::LDAP",
		      "../cpan/download.cgi?source=3&cpan=Net::LDAP&".
		      "cpan=Convert::ASN1&".
		      "return=../$module_name/&returndesc=".
		      &urlize($module_info{'desc'}));
		}
	return $msg;
	}

# Work out server name, login and TLS mode
local ($server, $port, $user, $pass, $ssl);
if ($config{'server'}) {
	# Remote box .. everything must be set
	$server = $config{'server'};
	&to_ipaddress($server) || return &text('connect_eserver',
					       "<tt>$server</tt>");
	$port = $config{'port'};
	$user = $config{'user'};
	$user || return $text{'connect_euser'};
	$pass = $config{'pass'};
	$pass || return $text{'connect_epass'};
	}
else {
	# Get from slapd.conf
	-e $config{'config_file'} || return &text('connect_efile',
					"<tt>$config{'config_file'}</tt>");
	$server = "127.0.0.1";
	$port = $config{'port'};
	$user = $config{'user'};
	$pass = $config{'pass'};
	if (&get_config_type() == 1) {
		# Find defaults from slapd.conf
		local $conf = &get_config();
		$port ||= &find_value("port", $conf);
		$user ||= &find_value("rootdn", $conf);
		$pass ||= &find_value("rootpw", $conf);
		}
	else {
		# Find defaults from LDIF-format data
		local $conf = &get_ldif_config();
		$defdb = &get_default_db();
		$port ||= &find_ldif_value("olcPort", $conf, $defdb);
		$user ||= &find_ldif_value("olcRootDN", $conf, $defdb);
		$pass ||= &find_ldif_value("olcRootPW", $conf, $defdb);
		}
	$user || return $text{'connect_euser2'};
	$pass =~ /^\{/ && return $text{'connect_epass3'};
	}
$ssl = $config{'ssl'};

# Call generic LDAP client function to connect
&foreign_require("ldap-client", "ldap-client-lib.pl");
local @ssls = $ssl eq "" ? ( 1, 2, 0 ) : ( $ssl );
local $ldap;
foreach $ssl (@ssls) {
	my $sslport = $port ? $port : $ssl == 1 ? 636 : 389;
	$ldap = &ldap_client::generic_ldap_connect($server, $sslport, $ssl,
					           $user, $pass);
	if (!ref($ldap)) {
		# Failed .. but try again in other SSL mode
		if ($ssl == $ssls[$#ssls]) {
			return $ldap;
			}
		}
	}
$ldap || return "This can't happen!";

$connect_ldap_db = $ldap;
return $ldap;
}

# get_default_db()
# For LDIF format configs, returns the config DN for the default database
sub get_default_db
{
local @poss = (
		"olcDatabase={1}hdb,cn=config",
		"olcDatabase={1}bdb,cn=config",
		"olcDatabase={1}mdb,cn=config",
		"olcDatabase={2}hdb,cn=config",
		"olcDatabase={2}bdb,cn=config",
		"olcDatabase={2}mdb,cn=config",
	      );
foreach my $p (@poss) {
	local @w = split(/,/, $p);
	if (-r $config{'config_file'}."/".join("/", reverse(@w)).".ldif") {
		return $p;
		}
	}
return $poss[$#poss];
}

sub get_config_db
{
return "cn=config";
}

# local_ldap_server()
# Returns 1 if OpenLDAP is installed locally and we are configuring it, 0 if
# remote, or -1 the binary is missing, -2 if the config is missing
sub local_ldap_server
{
if (!$config{'server'} || &to_ipaddress($config{'server'}) eq '127.0.0.1' ||
    &to_ipaddress($config{'server'}) eq &to_ipaddress(&get_system_hostname())) {
	# Local .. but is it installed?
	if (!-r $config{'config_file'} &&
	    -r $config{'alt_config_file'}) {
		&copy_source_dest($config{'alt_config_file'},
				  $config{'config_file'});
		}
	return !&has_command($config{'slapd'}) ? -1 :
	       !&get_config_type() ? -2 : 1;
	}
return 0;
}

# get_ldap_server_version()
# Returns the local LDAP server version number
sub get_ldap_server_version
{
return undef if (&local_ldap_server() != 1);
local $out = &backquote_with_timeout(
		"$config{'slapd'} -V -d 1 2>&1 </dev/null", 1, 1, 20);
if ($out =~ /slapd\s+([0-9\.]+)/) {
	return $1;
	}
# Fall back to -d flag
local $out = &backquote_with_timeout("$config{'slapd'} -d 255 2>&1 </dev/null",
				     1, 1, 1);
if ($out =~ /slapd\s+([0-9\.]+)/) {
	return $1;
	}
return undef;
}

# get_config_type()
# Returns 2 for new-style LDIF format directory, 1 for slapd.conf, 0 if unknown
sub get_config_type
{
if (-d $config{'config_file'} && -r "$config{'config_file'}/cn=config.ldif") {
	return 2;
	}
elsif (-r $config{'config_file'}) {
	return 1;
	}
else {
	return 0;
	}
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
			       'eline' => $lnum,
			       'file' => $file };
		local $value = $2;
		$dir->{'values'} = [ &split_quoted_string($value) ];
		push(@rv, $dir);
		}
	elsif (/^\s+(\S.*)$/ && @rv) {
		# Found a continuation line, with extra values
		local $value = $1;
		push(@{$rv[$#rv]->{'values'}}, &split_quoted_string($value));
		$rv[$#rv]->{'eline'} = $lnum;
		}
	$lnum++;
	}
close(CONF);
$get_config_cache{$file} = \@rv;
return \@rv;
}

# find(name, &config)
# Returns the structure(s) with some name
sub find
{
local ($name, $conf) = @_;
local @rv = grep { lc($_->{'name'}) eq lc($name) } @$conf;
return wantarray ? @rv : $rv[0];
}

# find_value(name, &config)
# Returns the directive values with some name
sub find_value
{
local ($name, $conf) = @_;
local @rv = map { $_->{'values'}->[0] } &find(@_);
return wantarray ? @rv : $rv[0];
}

# find_ldif(name, &config, [class])
# Returns the structures with some name and optionally class in the LDIF
# configuration array ref
sub find_ldif
{
local ($name, $conf, $cls) = @_;
local @rv = grep { lc($_->{'name'}) eq lc($name) } @$conf;
if ($cls) {
	@rv = grep { lc($_->{'class'}) eq lc($cls) } @rv;
	}
return wantarray ? @rv : $rv[0];
}

# find_ldif_value(name, &config, [class])
# Returns the values with some name and optionally class in the LDIF
# configuration array ref
sub find_ldif_value
{
local ($name, $conf, $cls) = @_;
local @rv = map { $_->{'values'}->[0] } &find_ldif(@_);
return wantarray ? @rv : $rv[0];
}

# get_ldif_config()
# Parses the new LDIF-format config files into a list ref
sub get_ldif_config
{
if (defined($get_ldif_config_cache)) {
	return $get_ldif_config_cache;
	}
local @rv;
foreach my $file (&recursive_find_ldif($config{'config_file'})) {
	local $lnum = 0;
	local $cls = $file;
	$cls =~ s/^\Q$config{'config_file'}\/\E//;
	$cls =~ s/\.ldif$//;
	$cls = join(",", reverse(split(/\//, $cls)));
	open(CONFIG, $file);
	while(<CONFIG>) {
		s/\r|\n//g;
		s/^#.*$//;
		if (/^([^: \t]+)(:+)\s*(.*)/) {
			# Start of a directive
			local $dir = { 'file' => $file,
				       'line' => $lnum,
				       'eline' => $lnum,
				       'class' => $cls,
				       'name' => $1 };
			local $value = $3;
			if ($2 eq "::") {
				# Base-64 decode value
				$value = &decode_base64($value);
				}
			$dir->{'values'} = [ &split_quoted_string($value) ];
			$dir->{'value'} = $value;
			push(@rv, $dir);
			}
		elsif (/^\s(\s*\S.*)$/ && @rv && $rv[$#rv]->{'file'} eq $file) {
			# Continuation line
			local $dir = $rv[$#rv];
			$dir->{'value'} .= $1;
			$dir->{'values'} =
				[ &split_quoted_string($dir->{'value'}) ];
			$dir->{'eline'} = $lnum;
			}
		$lnum++;
		}
	close(CONFIG);
	}
$get_ldif_config_cache = \@rv;
return $get_ldif_config_cache;
}

# recursive_find_ldif(dir)
# Find all .ldif files under some directory
sub recursive_find_ldif
{
local ($dir) = @_;
local @rv;
opendir(LDIFDIR, $dir);
local @files = readdir(LDIFDIR);
closedir(LDIFDIR);
foreach my $f (@files) {
	next if ($f eq "." || $f eq "..");
	local $path = "$dir/$f";
	if (-r $path && $path =~ /\.ldif$/) {
		push(@rv, $path);
		}
	elsif (-d $path) {
		push(@rv, &recursive_find_ldif($path));
		}
	}
return @rv;
}

# save_directive(&config, name, value|&values|&directive, ...)
# Update the value(s) of some entry in the config file
sub save_directive
{
local ($conf, $name, @values) = @_;
local @old = &find($name, $conf);
local $lref = &read_file_lines(@old ? $old[0]->{'file'}
				    : $config{'config_file'});
local $changed;
for(my $i=0; $i<@old || $i<@values; $i++) {
	local ($line, @unqvalues, @qvalues, $len);
	if (defined($values[$i])) {
		# Work out new line
		@unqvalues = ref($values[$i]) eq 'ARRAY' ?
				@{$values[$i]} :
			     ref($values[$i]) eq 'HASH' ?
				@{$values[$i]->{'values'}} :
				( $values[$i] );
		@qvalues = map { /^[^'" ]+$/ ? $_ :
				 /"/ ? "'$_'" : "\"$_\"" } @unqvalues;
		$line = join(" ", $name, @qvalues);
		}
	if (defined($old[$i])) {
		$len = $old[$i]->{'eline'} - $old[$i]->{'line'} + 1;
		}
	if (defined($old[$i]) && defined($values[$i])) {
		# Update some directive
		splice(@$lref, $old[$i]->{'line'}, $len, $line);
		if (&indexof($values[$i], @$conf) < 0) {
			$old[$i]->{'values'} = \@unqvalues;
			}
		$old[$i]->{'eline'} = $old[$i]->{'line'};
		$changed = $old[$i];
		if ($len != 1) {
			# Renumber to account for shrunked directive
			foreach my $c (@$conf) {
				if ($c->{'line'} > $old[$i]->{'line'}) {
					$c->{'line'} -= $len-1;
					$c->{'eline'} -= $len-1;
					}
				}
			}
		}
	elsif (defined($old[$i]) && !defined($values[$i])) {
		# Remove some directive (from cache too)
		splice(@$lref, $old[$i]->{'line'}, $len);
		local $idx = &indexof($old[$i], @$conf);
		splice(@$conf, $idx, 1) if ($idx >= 0);
		foreach my $c (@$conf) {
			if ($c->{'line'} > $old[$i]->{'line'}) {
				$c->{'line'} -= $len;
				$c->{'eline'} -= $len;
				}
			}
		}
	elsif (!defined($old[$i]) && defined($values[$i])) {
		# Add some directive
		if ($changed) {
			# After last one of the same name
			local $newdir = { 'name' => $name,
					  'line' => $changed->{'line'}+1,
					  'eline' => $changed->{'line'}+1,
					  'values' => \@unqvalues };
			foreach my $c (@$conf) {
				$c->{'line'}++ if ($c->{'line'} > 
						   $changed->{'line'});
				}
			$changed = $newdir;
			splice(@$lref, $newdir->{'line'}, 0, $line);
			push(@$conf, $newdir);
			}
		else {
			# At end of file, or over commented directive
			my $cmtline = undef;
			for(my $i=0; $i<@$lref; $i++) {
				if ($lref->[$i] =~ /^\s*\#+\s*(\S+)/ &&
				    $1 eq $name) {
					$cmtline = $i;
					last;
					}
				}
			if (defined($cmtline)) {
				# Over comment
				local $newdir = { 'name' => $name,
						  'line' => $cmtline,
						  'eline' => $cmtline,
						  'values' => \@unqvalues };
				$lref->[$cmtline] = $line;
				push(@$conf, $newdir);
				}
			else {
				# Really at end
				local $newdir = { 'name' => $name,
						  'line' => scalar(@$lref),
						  'eline' => scalar(@$lref),
						  'values' => \@unqvalues };
				push(@$lref, $line);
				push(@$conf, $newdir);
				}
			}
		}
	}
}

# save_ldif_directive(&config, name, class, value|&values|&directive, ...)
# Update the value(s) of some entry in the LDIF format config file
sub save_ldif_directive
{
local ($conf, $name, $cls, @values) = @_;
local @old = &find_ldif($name, $conf, $cls);
local $file;
if (@old) {
	$file = $old[0]->{'file'};
	}
else {
	local ($first) = grep { lc($_->{'class'}) eq lc($cls) } @$conf;
	$first || &error("No LDIF-format config file found for $cls");
	$file = $first->{'file'};
	}
local $lref = &read_file_lines($file);
for(my $i=0; $i<@old || $i<@values; $i++) {
	local ($line, @unqvalues, @qvalues, $len);
	local $oldlen = defined($old[$i]) ?
		$old[$i]->{'eline'} - $old[$i]->{'line'} + 1 : undef;
	if (defined($values[$i])) {
		# Work out new line
		@unqvalues = ref($values[$i]) eq 'ARRAY' ?
                                @{$values[$i]} :
                             ref($values[$i]) eq 'HASH' ?
                                @{$values[$i]->{'values'}} :
                                ( $values[$i] );
		$line = $name.": ".join(" ", @unqvalues);
		}
	if (defined($old[$i]) && defined($values[$i])) {
		# Update some directive
		$lref->[$old[$i]->{'line'}] = $line;
		if (&indexof($values[$i], @$conf) < 0) {
			$old[$i]->{'values'} = \@unqvalues;
			}
		$old[$i]->{'eline'} = $old[$i]->{'line'};
		if ($oldlen > 1) {
			# Remove extra old lines
			splice(@$lref, $old[$i]->{'line'}+1, $oldlen-1);
			foreach my $c (@$conf) {
				if ($c->{'line'} > $old[$i]->{'line'}) {
					$c->{'line'} -= $oldlen - 1;
					$c->{'eline'} -= $oldlen - 1;
					}
				}
			}
		}
	elsif (defined($old[$i]) && !defined($values[$i])) {
		# Remove some directive (from cache too)
		splice(@$lref, $old[$i]->{'line'}, $oldlen);
		local $idx = &indexof($old[$i], @$conf);
                splice(@$conf, $idx, 1) if ($idx >= 0);
	        foreach my $c (@$conf) {
                        if ($c->{'line'} > $old[$i]->{'line'}) {
                                $c->{'line'} -= $oldlen;
                                $c->{'eline'} -= $oldlen;
                                }
                        }
		}
	elsif (!defined($old[$i]) && defined($values[$i])) {
		# Add some directive
		local $newdir = { 'name' => $name,
				  'line' => scalar(@$lref),
				  'eline' => scalar(@$lref),
				  'file' => $file,
				  'values' => \@unqvalues };
		push(@$lref, $line);
		push(@$conf, $newdir);
		}
	}
}

# start_ldap_server()
# Attempts to start the LDAP server process. Returns undef on success or an
# error message on failure.
sub start_ldap_server
{
local $cmd = $config{'start_cmd'} || $config{'slapd'};
local $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $? || $out =~ /line\s+(\d+)/ ?
	&text('start_ecmd', "<tt>$cmd</tt>",
	      "<pre>".&html_escape($out)."</pre>") : undef;
}

# stop_ldap_server()
# Attempts to stop the running LDAP server. Returns undef on success or an
# error message on failure.
sub stop_ldap_server
{
if ($config{'stop_cmd'}) {
	local $out = &backquote_logged("$config{'stop_cmd'} 2>&1 </dev/null");
	return $? ? &text('stop_ecmd', "<tt>$cmd</tt>",
			  "<pre>".&html_escape($out)."</pre>") : undef;
	}
else {
	local $pid = &is_ldap_server_running();
	$pid || return $text{'stop_egone'};
	return kill('TERM', $pid) ? undef : &text('stop_ekill', $!);
	}
}

# apply_configuration()
# Apply the current LDAP server configuration with a HUP signal
sub apply_configuration
{
if ($config{'apply_cmd'}) {
	local $out = &backquote_logged("$config{'apply_cmd'} 2>&1 </dev/null");
	return $? ? &text('apply_ecmd', "<tt>$cmd</tt>",
			  "<pre>".&html_escape($out)."</pre>") : undef;
	}
else {
	local $err = &stop_ldap_server();
	return $err if ($err);
	return &start_ldap_server();
	}
}

# get_ldap_server_pidfile()
# Returns the LDAP server's PID file, or undef if not found
sub get_ldap_server_pidfile
{
if (&get_config_type() == 1) {
	local $conf = &get_config();
	return &find_value("pidfile", $conf);
	}
else {
	local $conf = &get_ldif_config();
	return &find_value("olcPidFile", $conf);
	}
}

# is_ldap_server_running()
# Returns the process ID of the running LDAP server, or undef
sub is_ldap_server_running
{
local $pidfile = &get_ldap_server_pidfile();
if ($pidfile) {
	return &check_pid_file($pidfile);
	}
return undef;
}

# ldap_error(rv)
# Converts a bad LDAP response into an error message
sub ldap_error
{
local ($rv) = @_;
if (!$rv) {
	return $text{'euknown'};
	}
elsif ($rv->code) {
	return $rv->error || "Code ".$rv->code;
	}
else {
	return undef;
	}
}

# valid_pem_file(file, type)
sub valid_pem_file
{
local ($file, $type) = @_;
local $data = &read_file_contents($file);
if ($type eq 'key') {
	return $data =~ /\-{5}BEGIN (RSA )?PRIVATE KEY\-{5}/ &&
	       $data =~ /\-{5}END (RSA )?PRIVATE KEY\-{5}/;
	}
else {
	return $data =~ /\-{5}BEGIN CERTIFICATE\-{5}/ &&
	       $data =~ /\-{5}END CERTIFICATE\-{5}/;
	}
}

sub get_config_dir
{
if (-d $config{'config_file'}) {
	return $config{'config_file'};
	}
if ($config{'config_file'} =~ /^(\S+)\/([^\/]+)$/) {
	return $1;
	}
return undef;
}

# list_schema_files()
# Returns a list of hashes, each of which describes one possible schema file
sub list_schema_files
{
local @rv;
opendir(SCHEMA, $config{'schema_dir'});
foreach my $f (readdir(SCHEMA)) {
	if ($f =~ /^(\S+)\.schema$/) {
		local $name = $1;
		local $lref = &read_file_lines("$config{'schema_dir'}/$f", 1);
		local $desc;
		foreach my $l (@$lref) {
			if ($l !~ /^\#+\s*\$/ && $l =~ /^\#+\s*([^#]\S.*)/) {
				$desc .= $1." ";	# Comment
				}
			elsif ($l !~ /\S/) {
				last;			# End of header
				}
			else {
				last if ($desc);	# End of comment
				}
			}
		$desc ||= $text{'schema_desc_'.$name};
		push(@rv, { 'file' => "$config{'schema_dir'}/$f",
			    'name' => $name,
			    'desc' => $desc,
			    'core' => $name eq 'core' });
		}
	}
closedir(SCHEMA);
return sort { $b->{'core'} <=> $a->{'core'} ||
	      $a->{'name'} cmp $b->{'name'} } @rv;
}

# check_ldap_permissions()
# Returns 1 if ownership of the data dir is correct, 0 if not, -1 if not known
sub check_ldap_permissions
{
local @uinfo;
if ($config{'data_dir'} && $config{'ldap_user'} &&
    scalar(@uinfo = getpwnam($config{'ldap_user'}))) {
	opendir(DATADIR, $config{'data_dir'});
	local @datafiles = grep { !/^\./ } readdir(DATADIR);
	closedir(DATADIR);
	if (@datafiles) {
		local @st = stat("$config{'data_dir'}/$datafiles[0]");
		if ($st[4] != $uinfo[2]) {
			return 0;
			}
		}
	return 1;
	}
else {
	return -1;
	}
}

# parse_ldap_access(&directive)
# Convert a slapd.conf directive into a more usable access control rule hash
sub parse_ldap_access
{
local ($a) = @_;
local @v = @{$a->{'values'}};
local $p = { };
if ($v[0] =~ /^\{(\d+)\}/) {
	$p->{'order'} = $1;
	}
shift(@v);			# Remove to or {x}to
if ($v[0] !~ /^(filter|attrs)=/) {
	$p->{'what'} = shift(@v);	# Object
	}
if ($v[0] =~ /^filter=(\S+)/) {
	# Filter added to what
	$p->{'filter'} = $1;
	shift(@v);
	}
if ($v[0] =~ /^attrs=(\S+)/) {
	# Attributes added to what
	$p->{'attrs'} = $1;
	shift(@v);
	}
local @descs;
while(@v) {
	shift(@v);		# Remove by
	local $by = { 'who' => shift(@v),
		      'access' => shift(@v) };
	while(@v && $v[0] ne 'by') {
		push(@{$by->{'control'}}, shift(@v));
		}
	local $whodesc = $by->{'who'} eq 'self' ? $text{'access_self'} :
			 $by->{'who'} eq 'users' ? $text{'access_users'} :
			 $by->{'who'} eq 'anonymous' ? $text{'access_anon'} :
			 $by->{'who'} eq '*' ? $text{'access_all'} :
					       "<tt>$by->{'who'}</tt>";
	local $adesc = $text{'access_'.$by->{'access'}} ||
		       "<tt>$by->{'access'}</tt>";
	$adesc = ucfirst($adesc) if (!@descs);
	push(@descs, &text('access_desc', $whodesc, $adesc));
	push(@{$p->{'by'}}, $by);
	}
$p->{'bydesc'} = join(", ", @descs);
if ($p->{'what'} eq '*' || $p->{'what'} eq '') {
	$p->{'whatdesc'} = $text{'access_any'};
	}
elsif ($p->{'what'} =~ /^dn(\.[^=]+)?="(.*)"$/ ||
       $p->{'what'} =~ /^dn(\.[^=]+)?=(.*)$/) {
	$p->{'whatdesc'} = $2 ne '' ? "<tt>$2</tt>" : $text{'access_nodn'};
	}
else {
	$p->{'whatdesc'} = $p->{'what'};
	}
return $p;
}

# store_ldap_access(&directive, &acl-struct)
# Updates the values of a directive from an ACL structure
sub store_ldap_access
{
local ($a, $p) = @_;
local @v = ( 'to' );
if ($p->{'order'}) {
	$v[0] = "{".$p->{'order'}."}".$v[0];
	}
push(@v, $p->{'what'});
if ($p->{'filter'}) {
	push(@v, "filter=$p->{'filter'}");
	}
if ($p->{'attrs'}) {
	push(@v, "attrs=$p->{'attrs'}");
	}
foreach my $b (@{$p->{'by'}}) {
	push(@v, "by");
	push(@v, $b->{'who'});
	push(@v, $b->{'access'});
	push(@v, @{$b->{'control'}});
	}
$a->{'values'} = \@v;
}

# can_get_ldap_protocols()
# Returns 1 if we can get the protocols this LDAP server will serve. Depends
# on the OS, as this is often set in the init script.
sub can_get_ldap_protocols
{
return $gconfig{'os_type'} eq 'redhat-linux' &&
	-r "/etc/sysconfig/ldap" ||
       $gconfig{'os_type'} eq 'debian-linux' &&
	-r "/etc/default/slapd" &&
	&get_ldap_protocols();
}

# get_ldap_protocols()
# Returns a hash from known LDAP protcols (like ldap, ldaps and ldapi) to
# flags indicating if they are enabled
sub get_ldap_protocols
{
if ($gconfig{'os_type'} eq 'redhat-linux') {
	# Stored in /etc/sysconfig/ldap file
	local %ldap;
	&read_env_file("/etc/init.d/ldap", \%ldap);
	&read_env_file("/etc/sysconfig/ldap", \%ldap);
	if (!$ldap{'SLAPD_LDAP'} &&
	    !$ldap{'SLAPD_LDAPI'} &&
	    !$ldap{'SLAPD_LDAPS'}) {
		&read_env_file("/etc/sysconfig/ldap", \%ldap, 1);
		}
	return { 'ldap' => $ldap{'SLAPD_LDAP'} eq 'yes' ? 1 : 0,
		 'ldapi' => $ldap{'SLAPD_LDAPI'} eq 'yes' ? 1 : 0,
		 'ldaps' => $ldap{'SLAPD_LDAPS'} eq 'yes' ? 1 : 0,
	       };
	}
elsif ($gconfig{'os_type'} eq 'debian-linux') {
	# Stored in /etc/default/slapd, in SLAPD_SERVICES line
	local %ldap;
	&read_env_file("/etc/default/slapd", \%ldap);
	if ($ldap{'SLAPD_SERVICES'}) {
		local @servs = split(/\s+/, $ldap{'SLAPD_SERVICES'});
		local $rv = { 'ldap' => 0, 'ldaps' => 0, 'ldapi' => 0 };
		foreach my $w (@servs) {
			if ($w =~ /^(ldap|ldaps|ldapi):\/\/\/$/) {
				$rv->{$1} = 1;
				}
			else {
				# Unknown protocol spec .. ignore
				return undef;
				}
			}
		return $rv;
		}
	else {
		# Default is non-encrypted only
		return { 'ldap' => 1, 'ldaps' => 0, 'ldapi' => 0 };
		}
	}
}

# save_ldap_protocols(&protos)
# Updates the OS-specific file containing enabled LDAP protocols. Also does
# locking on the file.
sub save_ldap_protocols
{
local ($protos) = @_;
if ($gconfig{'os_type'} eq 'redhat-linux') {
	# Stored in /etc/sysconfig/ldap file
	local %ldap;
	&lock_file("/etc/sysconfig/ldap");
	&read_env_file("/etc/sysconfig/ldap", \%ldap);
	$ldap{'SLAPD_LDAP'} = $protos->{'ldap'} ? 'yes' : 'no'
		if (defined($protos->{'ldap'}));
	$ldap{'SLAPD_LDAPI'} = $protos->{'ldapi'} ? 'yes' : 'no'
		if (defined($protos->{'ldapi'}));
	$ldap{'SLAPD_LDAPS'} = $protos->{'ldaps'} ? 'yes' : 'no'
		if (defined($protos->{'ldaps'}));
	&write_env_file("/etc/sysconfig/ldap", \%ldap);
	&unlock_file("/etc/sysconfig/ldap");
	}
elsif ($gconfig{'os_type'} eq 'debian-linux') {
	# Update /etc/default/slapd SLAPD_SERVICES line
	local %ldap;
	&lock_file("/etc/default/slapd");
	&read_env_file("/etc/default/slapd", \%ldap);
	$ldap{'SLAPD_SERVICES'} =
	    join(" ", map { $_.":///" } grep { $protos->{$_} } keys %$protos);
	&write_env_file("/etc/default/slapd", \%ldap);
	&unlock_file("/etc/default/slapd");
	}
}

sub get_ldap_base
{
if (&get_config_type() == 1) {
	my $conf = &get_config();
	my $base = &find_value("suffix", $conf);
	return $base;
	}
elsif (&get_config_type() == 2) {
	my $conf = &get_ldif_config();
	my $base = &find_ldif_value("olcSuffix", $conf, &get_default_db());
	return $base;
	}
return undef;
}

# lock_slapd_files()
# Lock all LDAP config file(s)
sub lock_slapd_files
{
if (&get_config_type() == 2) {
	@ldap_lock_files = &recursive_find_ldif($config{'config_file'});
	}
else {
	@ldap_lock_files = ( $config{'config_file'} );
	}
foreach my $f (@ldap_lock_files) {
	&lock_file($f);
	}
}

# unlock_slapd_files()
# Un-lock all LDAP config file(s)
sub unlock_slapd_files
{
foreach my $f (@ldap_lock_files) {
	&unlock_file($f);
	}
@ldap_lock_files = ( );
}

1;

