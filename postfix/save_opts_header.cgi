#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# Save Postfix options ; special because for virtual tables


require './postfix-lib.pl';

&ReadParse();


$access{'header'} || &error($text{'header_ecannot'});


&error_setup($text{'opts_err'});


&lock_postfix_files();
&before_save();
$in{'header_checks'} =~ /^(regexp|pcre):\/\S+$/ ||
	&error($text{'header_eregexp'});
&save_options(\%in);
&ensure_map("header_checks");
&after_save();
&unlock_postfix_files();


&regenerate_header_table();

$err = &reload_postfix();
&error($err) if ($err);

&webmin_log("header");
&redirect("");



