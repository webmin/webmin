#!/usr/local/bin/perl
# config_save.cgi
# Save inputs from edit_configs.cgi

require './usermin-lib.pl';
require '../config-lib.pl';
$access{'configs'} || &error($text{'acl_ecannot'});
&ReadParse();
&can_use_module($in{'mod'}) || &error($text{'configs_ecannot'});
$m = $in{'mod'};
&error_setup($text{'config_err'});
&get_usermin_miniserv_config(\%miniserv);

mkdir("$config{'usermin_dir'}/$m", 0700);
&lock_file("$config{'usermin_dir'}/$m/config");
&read_file("$config{'usermin_dir'}/$m/config", \%mconfig);

&parse_config(\%mconfig, "$miniserv{'root'}/$m/config.info");

&write_file("$config{'usermin_dir'}/$m/config", \%mconfig);
&unlock_file("$config{'usermin_dir'}/$m/config");
&webmin_log("config", undef, undef, \%in);
&redirect("list_configs.cgi");

