#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# Save Postfix options ; special because for aliases


require './postfix-lib.pl';

&ReadParse();

#      &ui_print_header(undef, $text{'opts_title'}, "");


&error_setup($text{'opts_err'});

&lock_postfix_files();
&before_save();
&save_options(\%in);
&ensure_map("alias_maps");
&ensure_map("alias_database");
&after_save();
&unlock_postfix_files();


&regenerate_aliases();
$err = &reload_postfix();
&error($err) if ($err);

&webmin_log("aliases");
&redirect("");



