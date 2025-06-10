#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# Save Postfix options ; special because for sni tables


require './postfix-lib.pl';

&ReadParse();


$access{'sni'} || &error($text{'sni_ecannot'});

&error_setup($text{'opts_err'});


&lock_postfix_files();
&before_save();
&save_options(\%in);
&ensure_map("tls_server_sni_maps");
&after_save();
&unlock_postfix_files();

&regenerate_sni_table();

$err = &reload_postfix();
&error($err) if ($err);

&webmin_log("sni");
&redirect("");



