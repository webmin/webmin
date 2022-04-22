#!/usr/bin/perl
# updateboot.pl
# Called by setup.sh to update boot script

$no_acl_check++;
require './init-lib.pl';
$product = $ARGV[0];

# Update boot script
if ($init_mode eq "systemd") {
	my $systemd_root = &get_systemd_root($product);
	if (-r "$systemd_root/webmin.service") {
		unlink("$systemd_root/webmin.service");
		copy_source_dest("../webmin-systemd", "$systemd_root/webmin.service");
		}
	elsif (-r "$systemd_root/webmin") {
		unlink("$systemd_root/webmin");
		copy_source_dest("../webmin-systemd", "$systemd_root/webmin");
		}
	system("systemctl --system daemon-reload >/dev/null 2>&1");
	};
