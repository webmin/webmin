#!/usr/local/bin/perl
# delboot.pl
# Called by uninstall.sh to stop webmin being started at boot time

$no_acl_check++;
require './init-lib.pl';
$product = $config{'atboot_product'} || "webmin";
$ucproduct = ucfirst($product);

if ($init_mode eq "local") {
	# Remove from /etc/webmin/start from boot time rc script
	open(LOCAL, "<".$config{'local_script'});
	@local = <LOCAL>;
	close(LOCAL);
	$start = "$config_directory/start";
	&open_tempfile(LOCAL, ">$config{'local_script'}");
	&print_tempfile(LOCAL, grep { !/^$start/ } @local);
	&close_tempfile(LOCAL);
	print "Deleted from bootup script $config{'local_script'}\n";
	}
else {
	# Use generic delete function
	&delete_at_boot($product);
	}
