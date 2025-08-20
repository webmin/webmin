# Dovecot 2.4 compatibility shims

# params([param])
# Simple mapping
sub params
{
my $name = shift;
my %map = (
	# Auth
	auth_default_realm     => 'auth_default_domain',
	disable_plaintext_auth => 'auth_allow_cleartext',

	# Mail
	mail_location          => 'mail_path',

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
# Translate key
sub map_find
{
my ($name) = @_;
return &params($name);
}

# Translate values
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

# Translate members
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

1;