#!/usr/local/bin/perl

require './postfix-lib.pl';

&ReadParse();

$access{'bcc'} || &error($text{'bcc_ecannot'});

&error_setup($text{'opts_err'});


&lock_postfix_files();
&before_save();
&save_options(\%in);
&ensure_map("sender_bcc_maps");
&ensure_map("recipient_bcc_maps");
&after_save();
&unlock_postfix_files();


&regenerate_bcc_table();
&regenerate_recipient_bcc_table();

$err = &reload_postfix();
&error($err) if ($err);

&webmin_log("bcc");
&redirect("");



