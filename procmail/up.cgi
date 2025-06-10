#!/usr/local/bin/perl
# up.cgi
# Move a recipe up in the file

require './procmail-lib.pl';
&ReadParse();
&lock_file($procmailrc);
@conf = &get_procmailrc();
&swap_recipes($conf[$in{'idx'}], $conf[$in{'idx'} - 1]);
&unlock_file($procmailrc);
&webmin_log("up");
&redirect("");

