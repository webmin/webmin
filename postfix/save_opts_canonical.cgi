#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# Save Postfix options ; special because for canonical tables


require './postfix-lib.pl';

&ReadParse();

$access{'canonical'} || &error($text{'canonical_ecannot'});

#      &ui_print_header(undef, $text{'opts_title'}, "");


&error_setup($text{'opts_err'});


&lock_postfix_files();
&before_save();
&save_options(\%in);
&ensure_map("canonical_maps");
&ensure_map("recipient_canonical_maps");
&ensure_map("sender_canonical_maps");
&after_save();
&unlock_postfix_files();


&regenerate_canonical_table();

$err = &reload_postfix();
&error($err) if ($err);

&webmin_log("canonical");
&redirect("");



