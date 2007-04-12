#!/usr/local/bin/perl
# change_lang.cgi
# Change language setting

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'lang_err'});
&lock_file("$config_directory/config");
$gconfig{'lang'} = $in{'lang'};
$gconfig{'acceptlang'} = $in{'acceptlang'};
if ($in{'charset_def'}) {
	delete($gconfig{'charset'});
	}
else {
	$in{'charset'} =~ /^\S+$/ || &error($text{'lang_echarset'});
	$gconfig{'charset'} = $in{'charset'};
	}
&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");
&webmin_log("lang", undef, undef, \%in);
&redirect("");

