# postinstall.pl
use strict;
use warnings;
no warnings 'redefine';
no warnings 'once';
no warnings 'uninitialized';

do 'nftables-lib.pl';

# module_install()
# Moves off the module's own rules file and boot action, which earlier
# releases used in place of the system nftables configuration
sub module_install
{
my ($moved, $removed);
eval {
	local $main::error_must_die = 1;
	$moved = &migrate_legacy_nftables_config();
	$removed = &remove_legacy_nftables_init();
	&remove_legacy_managed_metadata();
	};
if ($@) {
	print STDERR "Failed to migrate nftables configuration : $@\n";
	return;
	}
if ($moved) {
	print STDERR "Moved $moved nftables table(s) into ".
		     &nftables_rules_file()."\n";
	}
if ($removed && !&nftables_started_at_boot()) {
	print STDERR "The webmin-nftables boot action was removed, but the ".
		     "nftables service is not enabled at boot. Saved rules ".
		     "will not be loaded until it is.\n";
	}
}
