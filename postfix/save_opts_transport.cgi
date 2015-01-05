#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# Save Postfix options ; special because for transport tables


require './postfix-lib.pl';

&ReadParse();


$access{'transport'} || &error($text{'transport_ecannot'});
#      &ui_print_header(undef, $text{'opts_title'}, "");


&error_setup($text{'opts_err'});


&lock_postfix_files();
&before_save();
&save_options(\%in);
&ensure_map("transport_maps");
&after_save();
&unlock_postfix_files();

&regenerate_transport_table();

$err = &reload_postfix();
&error($err) if ($err);

&webmin_log("transport");
&redirect("");



