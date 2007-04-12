#!/usr/local/bin/perl
# Save FTP protocol options

require './frox-lib.pl';
&ReadParse();
&error_setup($text{'ftp_err'});
$conf = &get_config();

&save_yesno($conf, "APConv");
&save_yesno($conf, "PAConv");
!$in{'APConv'} || !$in{'PAConv'} || &error($text{'ftp_econv'});
&save_yesno($conf, "BounceDefend");
&save_yesno($conf, "SameAddress");
&save_yesno($conf, "AllowNonASCII");
&save_yesno($conf, "TransparentData");
&save_opt_range($conf, "ControlPorts");
&save_opt_range($conf, "PassivePorts");
&save_opt_range($conf, "ActivePorts");

&lock_file($config{'frox_conf'});
&flush_file_lines();
&unlock_file($config{'frox_conf'});
&webmin_log("ftp");
&redirect("");

