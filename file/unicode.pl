#!/usr/bin/perl

use Encode::HanConvert;

$ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
$ENV{'WEBMIN_VAR'} ||= "/var/webmin";
$no_acl_check++;
do './file-lib.pl';

@lang_order_list = ( "zh_TW.Big5" );
%big5 = &load_language($module_name);

foreach $k (keys %big5) {
	$unicode{$k} = big5_to_trad($big5{$k});
	}

&write_file("$module_root_directory/unicode/zh_TW.Big5", \%unicode);
