#!/usr/local/bin/perl
# Update the configuration for a module on multiple hosts

require './cluster-webmin-lib.pl';
require '../config-lib.pl';
&ReadParse();
&error_setup($text{'config_err'});

# Get the current config
@hosts = &list_webmin_hosts();
@servers = &list_servers();
($getfrom) = grep { $_->{'id'} == $in{'_getfrom'} } @hosts;
($serv) = grep { $_->{'id'} == $getfrom->{'id'} } @servers;
&remote_foreign_require($serv->{'host'}, "webmin", "webmin-lib.pl");
%fconfig = &remote_foreign_call($serv->{'host'}, "webmin", "foreign_config",
				$in{'mod'});

# Call the config parser
$mdir = &module_root_directory($in{'mod'});
if (-r "$mdir/config_info.pl") {
	# Module has a custom config editor
	&foreign_require($in{'mod'}, "config_info.pl");
	if (&foreign_defined($in{'mod'}, "config_save")) {
		$func++;
		&foreign_call($in{'mod'}, "config_save", \%fconfig);
		}
	}
if (!$func) {
	# Use config.info to parse config inputs
	&parse_config(\%fconfig, "$mdir/config.info", $in{'mod'});
	}

# Write out to all hosts
foreach $hid (split(/\0/, $in{'_host'})) {
	($serv) = grep { $_->{'id'} == $hid } @servers;
	if ($hid != $getfrom->{'id'}) {
		&remote_foreign_require($serv->{'host'}, "webmin", "webmin-lib.pl");
		}
	&remote_foreign_call($serv->{'host'}, "webmin", "save_module_config",
			     \%fconfig, $in{'mod'});
	}
&redirect("edit_mod.cgi?mod=$in{'mod'}");

