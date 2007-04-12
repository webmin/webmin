# uninstall.pl
# Called when webmin is uninstalled

require 'init-lib.pl';

sub module_uninstall
{
local %miniserv;
&get_miniserv_config(\%miniserv);
return if (!$miniserv{'atboot'});

local $product = $config{'atboot_product'} || "webmin";
local $ucproduct = ucfirst($product);

if ($init_mode eq "osx") {
	# Remove from hostconfig file
	open(LOCAL, $config{'hostconfig'});
	@local = <LOCAL>;
	close(LOCAL);
	$start = "WEBMIN=-";
	&open_tempfile(LOCAL, ">$config{'hostconfig'}");
	&print_tempfile(LOCAL, grep { !/^$start/ } @local);
	&close_tempfile(LOCAL);
	print STDERR "Deleted from $config{'hostconfig'}\n";
	# get rid of the startup items
	$paramlist = "$config{'darwin_setup'}/$ucproduct/$config{'plist'}";
	$scriptfile = "$config{'darwin_setup'}/$ucproduct/$ucproduct";
	print STDERR "Deleting $config{'darwin_setup'}/$ucproduct ..";
	unlink ($paramlist);
	unlink ($scriptfile);
	print STDERR "\. ", rmdir ("$config{'darwin_setup'}/$ucproduct") ? "Success":"Failed", "\n";
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
	print STDERR "Deleted from bootup script $config{'local_script'}\n";
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
	print STDERR "Deleted init script $fn\n";
	}
elsif ($init_mode eq "win32") {
	# Delete win32 service
	&delete_win32_service($product);
	}
}

1;

