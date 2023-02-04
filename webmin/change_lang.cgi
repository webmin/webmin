#!/usr/local/bin/perl
# change_lang.cgi
# Change language setting

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'lang_err'});
&lock_file("$config_directory/config");
$gconfig{'lang'} = $in{'lang'};
$gconfig{'langauto'} = int($in{'langauto'});
$gconfig{'acceptlang'} = $in{'acceptlang'};
$gconfig{'dateformat'} = $in{'dateformat'};
$gconfig{'locale'} = $in{'locale'};
$gconfig{'charset'} = 'UTF-8';
&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");
&webmin_log("lang", undef, undef, \%in);
&redirect("");

