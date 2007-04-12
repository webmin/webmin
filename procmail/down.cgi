#!/usr/local/bin/perl
# down.cgi
# Move a recipe down in the file

require './procmail-lib.pl';
&ReadParse();
&lock_file($procmailrc);
@conf = &get_procmailrc();
&swap_recipes($conf[$in{'idx'}], $conf[$in{'idx'} + 1]);
&unlock_file($procmailrc);
&webmin_log("down");
&redirect("");

