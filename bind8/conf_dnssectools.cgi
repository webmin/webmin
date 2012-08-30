#!/usr/local/bin/perl
# Show a form to setup DNSSEC-Tools parameters

require './bind8-lib.pl';

local $conf;
local $emailaddrs;
local $algorithm;
local $ksklength;
local $zsklength;
local $usensec3;
local $endtime;
local $ksklife;
local $zsklife;

&ReadParse();
$access{'defaults'} || &error($text{'dt_conf_ecannot'});
&ui_print_header(undef, $text{'dt_conf_title'}, "",
		 undef, undef, undef, undef, &restart_links());

print $text{'dt_conf_desc'},"<p>\n";

$conf = get_dnssectools_config();

print &ui_form_start("save_dnssectools.cgi", "post");
print &ui_table_start($text{'dt_conf_header'}, undef, 2);

$emailaddrs = find_value("admin-email", $conf);
print &ui_table_row($text{'dt_conf_email'},
		ui_textbox("dt_email", $emailaddrs, 50));

#algorithm; dt_alg
$algorithm = find_value("algorithm", $conf);
print &ui_table_row($text{'dt_conf_algorithm'},
		ui_textbox("dt_alg", $algorithm, 50));

#ksklength; dt_ksklen
$ksklength = find_value("ksklength", $conf);
print &ui_table_row($text{'dt_conf_ksklength'},
		ui_textbox("dt_ksklen", $ksklength, 50));

#zsklength; dt_zsklen
$zsklength = find_value("zsklength", $conf);
print &ui_table_row($text{'dt_conf_zsklength'},
		ui_textbox("dt_zsklen", $zsklength, 50));

#usensec3; dt_nsec3
$usensec3 = find_value("usensec3", $conf);
print &ui_table_row($text{'dt_conf_nsec3'},
		ui_textbox("dt_nsec3", $usensec3, 50));


#endtime; dt_endtime
$endtime = find_value("endtime", $conf);
print &ui_table_row($text{'dt_conf_endtime'},
		ui_textbox("dt_endtime", $endtime, 50));

print &ui_table_hr();

#ksklife; dt_ksklife
$ksklife = find_value("ksklife", $conf);
print &ui_table_row($text{'dt_conf_ksklife'},
		ui_textbox("dt_ksklife", $ksklife, 50));

#zsklife; dt_zsklife
$zsklife = find_value("zsklife", $conf);
print &ui_table_row($text{'dt_conf_zsklife'},
		ui_textbox("dt_zsklife", $zsklife, 50));

print &ui_table_hr();

# Interval in days
print &ui_table_row($text{'dnssec_period'},
	&ui_textbox("period", $config{'dnssec_period'} || 21, 5)." ".
	$text{'dnssec_days'});

print &ui_table_hr();
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

