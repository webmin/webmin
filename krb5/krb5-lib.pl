# krb5-lib.pl
# Common functions for the krb5 config

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

# get_config()
# Returns the krb5 config
sub get_config {
    local (%conf, $section, $realm);
    $section = $realm = "";
    open(FILE, $config{'krb5_conf'});
    while(<FILE>) {
	chomp;
	s/#.*//;
	s/^\s+//;
	s/\s+$//;
	if (/^\[/) { # section name
	    $section = $_;
	    $section =~ s/^\[([^\]]*)\]/\1/;
        }
	s/^\[.*$//;
	next unless length;
	my ($var, $value) = split(/\s*=\s*/, $_, 2);
	if ($section eq "logging") {
	    if ($value =~ /^FILE:/) { $value =~ s/^FILE://; }
	    $var = $var . "_log";
	}
	if (($section eq "domain_realm") and ($value eq $realm)) {
	    $value = $var;
	    $var = "domain";
	}
	if ($section eq "realms") {
	    if ($value =~ /\{/ ) {
		$realm = $var;
		$value = $var;
		$var = "realm";
	    }
	    if ($var eq "admin_server") {
		my $port;
		($value, $port) = split(':', $value, 2);
		$conf{'admin_port'} = $port;
	    }
	    if ($var eq "kdc") {
		my $port;
		($value, $port) = split(':', $value, 2);
		$conf{'kdc_port'} = $port;
	    }
	}
	$conf{$var} = $value;
    }
    close(FILE);
    return %conf;
}

1;
