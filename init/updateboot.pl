#!/usr/bin/perl
# updateboot.pl
# Called by setup.sh to update boot script

$no_acl_check++;
require './init-lib.pl';
$product = $ARGV[0];

$< == 0 || die "updateboot.pl must be run as root";

# Update boot script
if ($product) {
	if ($init_mode eq "systemd") {
		# Delete all possible service files
		my $systemd_root = &get_systemd_root();
		foreach my $p (
			"/etc/systemd/system",
			"/usr/lib/systemd/system",
			"/lib/systemd/system") {
			unlink("$p/$product.service");
			unlink("$p/$product");
			}
		copy_source_dest("../webmin-systemd", "$systemd_root/$product.service");
		system("systemctl daemon-reload >/dev/null 2>&1");
		};
	}
