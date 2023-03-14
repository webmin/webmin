# Common functions for the xterm module

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
our %access = &get_module_acl();
do "$module_root_directory/websockets-lib-funcs.pl";

# config_pre_load(mod-info-ref, [mod-order-ref])
# Check if some config options are conditional,
# and if not allowed, remove them from listing
sub config_pre_load
{
my ($modconf_info, $modconf_order) = @_;

if ($ENV{'HTTP_X_REQUESTED_WITH'} eq "XMLHttpRequest") {

	# Process forbidden keys
	my @forbidden_keys;
	
	# Size is not supported in Authentic, because resize works flawlessly and
	# making it work would just add addition complexity for no good reason
	push(@forbidden_keys, 'size');

	# Remove forbidden from display
	foreach my $fkey (@forbidden_keys) {
		delete($modconf_info->{$fkey});
		@{$modconf_order} = grep { $_ ne $fkey } @{$modconf_order}
			if ($modconf_order);
		}
	}
}

1;