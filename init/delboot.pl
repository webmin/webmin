#!/usr/local/bin/perl
# delboot.pl
# Called by uninstall.sh to stop webmin being started at boot time

$no_acl_check++;
require './init-lib.pl';
$product = $config{'atboot_product'} || "webmin";
$ucproduct = ucfirst($product);

if ($init_mode eq "osx") {
	# Remove from hostconfig file
	open(LOCAL, $config{'hostconfig'});
	@local = <LOCAL>;
	close(LOCAL);
	$start = "WEBMIN=-";
	&open_tempfile(LOCAL, ">$config{'hostconfig'}");
	&print_tempfile(LOCAL, grep { !/^$start/ } @local);
	&close_tempfile(LOCAL);
	print "Deleted from $config{'hostconfig'}\n";
	# get rid of the startup items
	$paramlist = "$config{'darwin_setup'}/$ucproduct/$config{'plist'}";
	$scriptfile = "$config{'darwin_setup'}/$ucproduct/$ucproduct";
	print "Deleting $config{'darwin_setup'}/$ucproduct ..";
	unlink ($paramlist);
	unlink ($scriptfile);
	print "\. ", rmdir ("$config{'darwin_setup'}/$ucproduct") ? "Success":"Failed", "\n";
	}
elsif ($init_mode eq "local") {
	# Remove from boot time rc script
	open(LOCAL, $config{'local_script'});
	@local = <LOCAL>;
	close(LOCAL);
	$start = "$config_directory/start";
	&open_tempfile(LOCAL, ">$config{'local_script'}");
	&print_tempfile(LOCAL, grep { !/^$start/ } @local);
	&close_tempfile(LOCAL);
	print "Deleted from bootup script $config{'local_script'}\n";
	}
elsif ($init_mode eq "init") {
	# Delete bootup action
	foreach (&action_levels('S', $product)) {
		/^(\S+)\s+(\S+)\s+(\S+)$/;
		&delete_rl_action($product, $1, 'S');
		}
	foreach (&action_levels('K', $product)) {
		/^(\S+)\s+(\S+)\s+(\S+)$/;
		&delete_rl_action($product, $1, 'K');
		}
	$fn = &action_filename($product);
	unlink($fn);
	print "Deleted init script $fn\n";
	}
elsif ($init_mode eq "win32") {
	# Delete win32 service
	&delete_win32_service($product);
	}
elsif ($init_mode eq "rc") {
	# Delete FreeBSD RC script
	&delete_rc_script($product);
	}
elsif ($init_mode eq "upstart") {
	# Delete upstart service
	&delete_upstart_service($product);
	}
elsif ($init_mode eq "systemd") {
	# Delete systemd service
	&delete_systemd_service($product.".service");
	}
