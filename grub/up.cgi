#!/usr/local/bin/perl
# Move a title up

require './grub-lib.pl';
&ReadParse();
&lock_file($config{'menu_file'});
$conf = &get_menu_config();
@t = &find("title", $conf);
&swap_directives($t[$in{'idx'}], $t[$in{'idx-1'}]);
&flush_file_lines($config{'menu_file'});
&unlock_file($config{'menu_file'});
&webmin_log("up", "title", undef, $t[$in{'idx'}]);
&redirect("");

