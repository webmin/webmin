#!/usr/local/bin/perl
# Move some filter up

require './filter-lib.pl';
&ReadParse();

&lock_file($procmail::procmailrc);
@filters = &list_filters();
&swap_filters($filters[$in{'idx'}], $filters[$in{'idx'}-1]);
&unlock_file($procmail::procmailrc);

&redirect("");

