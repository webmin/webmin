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
		my $reload_daemon = sub {
			system("systemctl daemon-reload >/dev/null 2>&1");
			sleep(2);
		};
		# Save status of service
		my $status = &backquote_logged("systemctl is-enabled ".
			quotemeta($product).".service 2>&1");
		$status = &trim($status) if ($status);
		# Delete all possible service files
		my $systemd_root = &get_systemd_root(undef, 1);
		foreach my $p (
			"/etc/systemd/system",
			"/usr/lib/systemd/system",
			"/lib/systemd/system") {
			unlink("$p/$product.service");
			unlink("$p/$product");
			}
		$reload_daemon->();

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
		$reload_daemon->();

		if ($status eq "disabled") {
			system("systemctl disable ".
				quotemeta($product).".service >/dev/null 2>&1");
			}
		elsif ($status eq "masked") {
			system("systemctl mask ".
				quotemeta($product).".service >/dev/null 2>&1");
			}
		else {
			system("systemctl enable ".
				quotemeta($product).".service >/dev/null 2>&1");
			}
		}
	elsif (-d "/etc/init.d") {
		copy_source_dest("$root_directory/webmin-init", "/etc/init.d/$product");
		system("chkconfig --add $product >/dev/null 2>&1");
		}
	}
