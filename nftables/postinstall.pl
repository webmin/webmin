# postinstall.pl
use strict;
use warnings;
no warnings 'redefine';
no warnings 'once';
no warnings 'uninitialized';

require 'nftables-lib.pl';    ## no critic

# module_install()
# Migrates private rules into the system configuration and removes the
# obsolete boot action
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
	# Remove the browser-only wrapper before writing the package error
	my $err = $@;
	$err =~ s/<\/?pre>//g;
	$err =~ s/\s+$//;
	print STDERR "Failed to migrate nftables configuration: $err\n";
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
