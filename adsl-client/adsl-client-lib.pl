# adsl-client-lib.pl
# Common functions for parsing the rp-pppoe config file

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
do 'secrets-lib.pl';

# get_config()
# Parse the PPPOE configuration file
sub get_config
{
local @rv;
local $lnum = 0;
open(FILE, $config{'pppoe_conf'}) || return undef;
while(<FILE>) {
	s/\r|\n//g;
	s/^\s*#.*$//;
	if (/^\s*(\S+)\s*=\s*"([^"]*)"/ ||
	    /^\s*(\S+)\s*=\s*'([^']*)'/ ||
	    /^\s*(\S+)\s*=\s*(\S+)/) {
		push(@rv, { 'name' => $1,
			    'value' => $2,
			    'line' => $lnum });
		}
	$lnum++;
	}
close(FILE);
return \@rv;
}

# find(name, &config)
# Looks up an entry in the config file
sub find
{
local $c;
foreach $c (@{$_[1]}) {
	if (lc($c->{'name'}) eq lc($_[0])) {
		return $c->{'value'};
		}
	}
return undef;
}

# save_directive(&config, name, value)
sub save_directive
{
local ($old) = grep { lc($_->{'name'}) eq lc($_[1]) } @{$_[0]};
local $lref = &read_file_lines($config{'pppoe_conf'});
local $nl = "$_[1]=".($_[2] =~ /^\S+$/ ? $_[2] : "\"$_[2]\"");
if ($old) {
	$lref->[$old->{'line'}] = $nl;
	}
else {
	push(@$lref, $nl);
	}
}

# get_adsl_ip()
# Returns the device name and IP address of the ADSL connection (if up),
# or nothing if down
sub get_adsl_ip
{
local $out = `$config{'status_cmd'} 2>&1`;
if ($out =~ /link is up/i &&
    $out =~ /on\s+interface\s+ppp(\d+)[\000-\377]+inet addr:\s*(\S+)/i) {
	return ($1, $2);
	}
elsif ($out =~ /attached\s+to\s+(ppp\d+)/i) {
	return ($1, undef);
	}
elsif ($out =~ /could\s+not\s+find\s+interface\s+corresponding\s+to/i) { 
        return ("unknown", undef) 
        } 
elsif ($out =~ /demand-connection/) {
	return ("demand", undef);
	}
else {
	return ( );
	}
}

# get_pppoe_version(&out)
sub get_pppoe_version
{
local $out = `$config{'pppoe_cmd'} -V 2>&1`;
${$_[0]} = $out;
return $out =~ /version\s+(\S+)/i ? $1 : undef;
}

1;

