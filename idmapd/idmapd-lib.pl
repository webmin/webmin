# idmapd-lib.pl
# Common functions for the idmapd config

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

# get_config()
# Returns the idmapd config
sub get_config {
    local %conf;
    open(FILE, $config{'idmapd_conf'});
    while(<FILE>) {
	chomp;
	s/#.*//;
	s/^\s+//;
	s/\s+$//;
	s/^\[.*$//;
	next unless length;
	my ($var, $value) = split(/\s*=\s*/, $_, 2);
	$conf{$var} = $value;
    }
    close(FILE);
    return %conf;
}

1;
