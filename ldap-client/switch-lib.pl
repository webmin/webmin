# Functions for parsing nsswitch.conf

$nsswitch_config_file = $config{'nsswitch_conf'} || "/etc/nsswitch.conf";

# get_nsswitch_config()
# Returns an array ref of information from nsswitch.conf
sub get_nsswitch_config
{
if (!scalar(@get_nsswitch_cache)) {
	@get_nsswitch_cache = ( );
	local $lnum = 0;
	open(CONF, $nsswitch_config_file);
	while(<CONF>) {
		s/\r|\n//g;
		s/#.*$//;
		if (/^\s*(\S+)\s*:\s*(.*)/) {
			# Found a switch config file
			local $switch = { 'name' => $1,
					  'line' => $lnum };
			local $servs = $2;
			local @srcs = ( );
			while($servs =~ /\S/) {
				if ($servs =~ /^\s*\[([^\]]*)\](.*)/) {
					# Actions for some source
					$servs = $2;
					foreach $av (split(/\s+/, $1)) {
						local ($a, $v) = split(/=/,$av);
						$srcs[$#srcs]->{lc($a)} =lc($v);
						}
					}
				elsif ($servs =~ /^\s*(\S+)(.*)/) {
					# A source
					push(@srcs, { 'src' => $1 });
					$servs = $2;
					}
				}
			$switch->{'srcs'} = \@srcs;
			push(@get_nsswitch_cache, $switch);
			}
		$lnum++;
		}
	close(CONF);
	}
return \@get_nsswitch_cache;
}

# save_nsswitch_config(&switch)
# Update one service
sub save_nsswitch_config
{
local ($switch) = @_;
local $lref = &read_file_lines($nsswitch_config_file);
local $line = "$switch->{'name'}:";
foreach my $s (@{$switch->{'srcs'}}) {
	$line .= " ".$s->{'src'};
	local @acts;
	foreach my $st (keys %$s) {
		if ($st ne "src") {
			push(@acts, uc($st)."=".$s->{$st});
			}
		}
	if (@acts) {
		$line .= " [".join(" ", @acts)."]";
		}
	}
$lref->[$switch->{'line'}] = $line;
&flush_file_lines($nsswitch_config_file);
}

# list_switch_sources()
# Returns a list of valid nsswitch.conf sources for this OS, and a map from
# sources to allowed services
sub list_switch_sources
{
if ($gconfig{'os_type'} =~ /-linux$/) {
	# All Linux variants
	return ( [ 'files', 'nisplus', 'nis', 'compat', 'dns', 'db',
		   'hesiod', 'ldap', 'sss' ],
		 { 'dns' => [ 'hosts' ],
		   'compat' => [ 'passwd', 'shadow', 'group' ] } );
	}
elsif ($gconfig{'os_type'} eq 'solaris' && $gconfig{'os_version'} < 8) {
	# Older Solaris
	return ( [ 'files', 'nis', 'nisplus', 'compat', 'dns' ],
		 { 'dns' => [ 'hosts' ],
		   'compat' => [ 'passwd', 'group' ] } );
	}
elsif ($gconfig{'os_type'} eq 'solaris' && $gconfig{'os_version'} >= 8) {
	# Newer Solaris
	return ( [ 'files', 'nis', 'nisplus', 'compat', 'dns', 'ldap',
		   'user', 'xfn' ],
		 { 'dns' => [ 'hosts' ],
		   'compat' => [ 'passwd', 'group' ],
		   'user' => [ 'printers' ],
		   'xfn' => [ 'printers' ] } );
	}
elsif ($gconfig{'os_type'} eq 'aix') {
	# IBM AIX
	return ( [ 'files', 'nis', 'nisplus', 'compat', 'dns', 'ldap',
		   'user', 'xfn' ],
		 { 'dns' => [ 'hosts' ],
		   'compat' => [ 'passwd', 'group' ],
		   'user' => [ 'printers' ],
		   'xfn' => [ 'printers' ] } );
	}
elsif ($gconfig{'os_type'} eq 'unixware') {
	# All Linux variants
	return ( [ 'files', 'dns', 'nis', 'nisplus' ],
		 { 'dns' => [ 'hosts' ] } );
	}
else {
	# Punt!
	return ( [ 'files', 'dns', 'nis', 'nisplus' ] );
	}
}

sub list_switch_statuses
{
return ( 'success', 'notfound', 'unavail', 'tryagain' );
}

sub list_switch_actions
{
return ( 'return', 'continue' );
}

1;

