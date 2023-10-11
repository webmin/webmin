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
		my $temp = &transname();
		my $killcmd = &has_command('kill');
		$ENV{'WEBMIN_KILLCMD'} = $killcmd;
		&copy_source_dest("$root_directory/webmin-systemd", "$temp");
		my $lref = &read_file_lines($temp);
		foreach my $l (@{$lref}) {
			$l =~ s/(WEBMIN_[A-Z]+)/$ENV{$1}/g;
			}
		&flush_file_lines($temp);
		copy_source_dest($temp, "$systemd_root/$product.service");
		system("systemctl daemon-reload >/dev/null 2>&1");
		}
	elsif (-d "/etc/init.d") {
		copy_source_dest("$root_directory/webmin-init", "/etc/init.d/$product");
		system("chkconfig --add $product >/dev/null 2>&1");
		}
	}
