#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# Save Postfix options ; special because for sender transport maps


require './postfix-lib.pl';

&ReadParse();


$access{'dependent'} || &error($text{'dependent_ecannot'});

&error_setup($text{'opts_err'});


&lock_postfix_files();
&before_save();
&save_options(\%in);
&ensure_map("sender_dependent_default_transport_maps");
&after_save();
&unlock_postfix_files();


&regenerate_dependent_table();

$err = &reload_postfix();
&error($err) if ($err);

&webmin_log("dependent");
&redirect("");



