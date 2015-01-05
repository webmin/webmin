#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# Save Postfix options ; special because for virtual tables


require './postfix-lib.pl';

&ReadParse();


$access{'body'} || &error($text{'body_ecannot'});


&error_setup($text{'opts_err'});


&lock_postfix_files();
&before_save();
$in{'body_checks'} =~ /^(regexp|pcre):\/\S+$/ ||
	&error($text{'body_eregexp'});
&save_options(\%in);
&ensure_map("body_checks");
&after_save();
&unlock_postfix_files();


&regenerate_body_table();

$err = &reload_postfix();
&error($err) if ($err);

&webmin_log("body");
&redirect("");



