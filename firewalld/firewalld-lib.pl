# Functions for managing firewalld
#
# XXX longdesc
# XXX makedist.pl
# XXX integration with other modules?
# XXX install_check
# XXX set zones for interfaces
# XXX detect use of firewalld in iptables modules

BEGIN { push(@INC, ".."); };
use strict;
use warnings;
use WebminCore;
&init_config();
do 'md5-lib.pl';
our ($module_root_directory, %text, %config, %gconfig);
our %access = &get_module_acl();

# check_firewalld()
# Returns an error message if firewalld is not installed, undef if all is OK
sub check_firewalld
{
&has_command($config{'firewall_cmd'}) ||
	return &text('check_ecmd', "<tt>".$config{'firewall_cmd'}."</tt>");
return undef;
}

# is_firewalld_running()
# Returns 1 if the server is running, 0 if not
sub is_firewalld_running
{
my $ex = system("$config{'firewall_cmd'} --state >/dev/null 2>&1 </dev/null");
return $ex ? 0 : 1;
}

# list_firewalld_zones()
# Returns an array of firewalld zones, each of which is a hash ref with fields
# like services and ports
sub list_firewalld_zones
{
my @rv;
my $out = &backquote_command("$config{'firewall_cmd'} --list-all-zones --permanent </dev/null 2>&1");
if ($?) {
	&error("Failed to list zones : $out");
	}
my $zone;
foreach my $l (split(/\r?\n/, $out)) {
	if ($l =~ /^(\S+)(\s+\(\S+\))?/) {
		# New zone
		$zone = { 'name' => $1,
			  'default' => $2 ? 1 : 0 };
		push(@rv, $zone);
		}
	elsif ($l =~ /^\s+(\S+):\s*(.*)/ && $zone) {
		# Option in some zone
		$zone->{$1} = [ split(/\s+/, $2) ];
		}
	}
return @rv;
}

1;

