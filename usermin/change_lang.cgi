#!/usr/local/bin/perl
# change_lang.cgi
# Change language setting

require './usermin-lib.pl';
$access{'lang'} || &error($text{'acl_ecannot'});
&ReadParse();
&lock_file($usermin_config);
&get_usermin_config(\%uconfig);
$uconfig{'lang'} = $in{'lang'};
$uconfig{'acceptlang'} = $in{'acceptlang'};
&put_usermin_config(\%uconfig);
&unlock_file($usermin_config);
&webmin_log("lang", undef, undef, \%in);
&redirect("");

