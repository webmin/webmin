#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# Save Postfix options ; special case in which we need to regenerate the relocated table


require './postfix-lib.pl';

&ReadParse();


#      &ui_print_header(undef, $text{'opts_title'}, "");


&error_setup($text{'opts_err'});


&lock_postfix_files();
&before_save();
&save_options(\%in, [ "myhostname", "mydomain" ]);
&ensure_map("relocated_maps");
&after_save();
&unlock_postfix_files();


&regenerate_relocated_table();

$err = &reload_postfix();
&error($err) if ($err);

&webmin_log("misc");
&redirect("");



