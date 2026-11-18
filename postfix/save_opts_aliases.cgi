#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# Save alias map settings and rebuild the alias databases.


require './postfix-lib.pl';    ## no critic
use strict;
use warnings;
our ($err, %access, %in, %text);

&ReadParse();

$access{'aliases'} || &error($text{'aliases_ecannot'});

#      &ui_print_header(undef, $text{'opts_title'}, "");


&error_setup($text{'opts_err'});

&lock_postfix_files();
&before_save();
&save_options(\%in, [ ], [ "alias_maps", "alias_database" ]);
&ensure_map("alias_maps");
&ensure_map("alias_database");
&after_save();
&unlock_postfix_files();


&regenerate_aliases();
$err = &reload_postfix();
&error($err) if ($err);

&webmin_log("aliases");
&redirect("");



