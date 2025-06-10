#!/usr/local/bin/perl
# rbootup.cgi
# Edit a redhat networking config file to determine if ADSL is started at 
# boot time or not

require './adsl-client-lib.pl';
&ReadParse();

&lock_file($config{'pppoe_conf'});
$conf = &get_config();
&save_directive($conf, "ONBOOT", $in{'onboot'} ? 'yes' : 'no');
&flush_file_lines();
&unlock_file($config{'pppoe_conf'});
&webmin_log($in{'onboot'} eq 'yes' ? 'bootup' : 'bootdown');
&redirect("");

