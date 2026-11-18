#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# Save mail routing map settings.


require './postfix-lib.pl';    ## no critic
use strict;
use warnings;
our ($err, %access, %in, %text);

&ReadParse();


$access{'transport'} || &error($text{'transport_ecannot'});
#      &ui_print_header(undef, $text{'opts_title'}, "");


&error_setup($text{'opts_err'});


&lock_postfix_files();
&before_save();
&save_options(\%in, [ ], [ "transport_maps" ]);
&ensure_map("transport_maps");
&after_save();
&unlock_postfix_files();

&regenerate_transport_table();

$err = &reload_postfix();
&error($err) if ($err);

&webmin_log("transport");
&redirect("");



