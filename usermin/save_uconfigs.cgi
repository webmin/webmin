#!/usr/local/bin/perl
# save_uconfigs.cgi
# Save default user inputs from edit_configs.cgi

require './usermin-lib.pl';
require '../config-lib.pl';
$access{'configs'} || &error($text{'acl_ecannot'});
&ReadParse();
&can_use_module($in{'mod'}) || &error($text{'configs_ecannot'});
$m = $in{'mod'};
&error_setup($text{'config_err'});
&get_usermin_miniserv_config(\%miniserv);

mkdir("$config{'usermin_dir'}/$m", 0700);
&lock_file("$config{'usermin_dir'}/$m/uconfig");
&read_file("$config{'usermin_dir'}/$m/uconfig", \%uconfig);

&parse_config(\%uconfig, "$miniserv{'root'}/$m/uconfig.info");

&write_file("$config{'usermin_dir'}/$m/uconfig", \%uconfig);
&unlock_file("$config{'usermin_dir'}/$m/uconfig");

# Save the preferences config as well
mkdir("$config{'usermin_dir'}/$m", 0700);
&lock_file("$config{'usermin_dir'}/$m/config");
&read_file("$config{'usermin_dir'}/$m/config", \%mconfig);
$mconfig{'noprefs'} = $in{'noprefs'} == 1 ? 1 : 0;
&write_file("$config{'usermin_dir'}/$m/config", \%mconfig);
&unlock_file("$config{'usermin_dir'}/$m/config");

# Save allowed options
%canconfig = map { $_, 1 } split(/\0/, $in{'_can'});
$canfile = "$config{'usermin_dir'}/$in{'mod'}/canconfig";
if ($in{'noprefs'} == 2) {
	# Save allowed list
	&write_file($canfile, \%canconfig);
	}
else {
	# All are allowed (or denied)
	&unlink_file($canfile);
	}

&webmin_log("uconfig", undef, undef, \%in);
&redirect("list_configs.cgi");

