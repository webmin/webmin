# Dovecot 2.4 compatibility shims

# %dovecot
# Dispatch table of 2.4 overrides keyed by sub name
our %dovecot = (
	find            => \&find_24,
	save_directive  => \&save_directive_24,
	save_section    => \&save_section_24,
	create_section  => \&create_section_24,
);

# dovecot(caller-sub, @args)
# Single entrypoint that routes a call to a version-specific override
sub dovecot
{
my ($sub, @args) = @_;
return if $dovecot{main};
(my $subname = $sub) =~ s/^.*:://;
if (my $thissub = $dovecot{$subname}) {
	return $thissub->(@args);
	}
my $mainsub = \&{$sub};
local $dovecot{main} = 1;
return $mainsub->(@args);
}

# params([param])
# Simple mapping
sub params
{
my $name = shift;
my %map = (
	# Auth
	auth_default_realm     => 'auth_default_domain',
	disable_plaintext_auth => 'auth_allow_cleartext',

	# SSL
	ssl_ca                 => 'ssl_server_ca_file',
	ssl_ca_file            => 'ssl_client_ca_file',
	ssl_cert               => 'ssl_server_cert_file',
	ssl_cert_file          => 'ssl_server_cert_file',
	ssl_key                => 'ssl_server_key_file',
	ssl_key_file           => 'ssl_server_key_file',
	ssl_key_password       => 'ssl_server_key_password',
	);
return wantarray ? %map : ($map{$name} || $name);
}

# map_find(name)
# Returns lookup key for compatibility
sub map_find
{
my ($name) = @_;
return &params($name);
}

# map_value(name, value)
# Converts values for compatibility
sub map_value
{
my ($name, $value) = @_;
$name = &map_find($name);

if ($name =~ /^(ssl_server_cert_file|ssl_server_key_file|ssl_server_ca_file|ssl_client_ca_file)$/) {
	# Drop obsolete "<"
	$value =~ s/^\s*<\s*// if defined $value;
	}
elsif ($name eq 'auth_allow_cleartext') {
	# Flip value
	$value = lc($value) eq 'no' ? 'yes' : 'no' if defined $value;
	}
return ($name, $value);
}

# map_members(members)
# Converts values to all members of a section
sub map_members
{
my ($members) = @_;
my @members;
for my $m (@{$members || []}) {
	my ($n, $v) = &map_value($m->{name}, $m->{value});
	my %copy = %$m;
	$copy{name}  = $n;
	$copy{value} = $v;
	push(@members, \%copy);
	}
return \@members;
}

# find_24(name, &config, [disabled-mode], [sectionname], [sectionvalue], [first])
# Finds mapped or original directive
sub find_24
{
local ($name, $conf, $mode, $sname, $svalue, $first) = @_;
my $req = $name;
$name = &map_find($name);

local $dovecot{main} = 1;
my @rv = &find($name, $conf, $mode, $sname, $svalue, undef);

foreach my $rv (@rv) {
	my (undef, $v) = &map_value($req, $rv->{value});
	$rv->{value} = $v;
	}

return @rv if wantarray;
return $rv[0] if $first;
return $rv[$#rv];
}

# save_directive_24(&conf, name|&dir, value, [sectionname], [sectionvalue])
# Updates mapped or original directive in the config file
sub save_directive_24
{
local ($conf, $name, $value, $sname, $svalue) = @_;
if (ref $name) {
	my ($nn, $vv) = &map_value($name->{name}, $value);
	$name->{name} = $nn; $value = $vv;
	local $dovecot{main} = 1;
	return &save_directive($conf, $name, $value, $sname, $svalue);
	}
else {
	my ($nn, $vv) = &map_value($name, $value);
	local $dovecot{main} = 1;
	return &save_directive($conf, $nn, $vv, $sname, $svalue);
	}
}

# save_section_24(&conf, &section)
# Updates one section in the config file with members mapped
sub save_section_24
{
local ($conf, $section) = @_;
$section->{members} = &map_members($section->{members});
local $dovecot{main} = 1;
return &save_section($conf, $section);
}

# create_section_24(&conf, &section, [&parent], [&before])
# Adds a section to the config file with members mapped
sub create_section_24
{
local ($conf, $section, $parent, $before) = @_;
$section->{members} = &map_members($section->{members});
local $dovecot{main} = 1;
return &create_section($conf, $section, $parent, $before);
}

1;