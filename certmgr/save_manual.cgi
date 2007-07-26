#!/usr/local/bin/perl
# Update the manually edited config file

require './certmgr-lib.pl';
&ReadParseMime();
&error_setup($text{'manual_err'});

$in{'data'} =~ s/\r//g;
$in{'data'} =~ /\S/ || &error($text{'manual_edata'});

&open_lock_tempfile(DATA, ">$config{'ssl_cnf_file'}");
&print_tempfile(DATA, $in{'data'});
&close_tempfile(DATA);

&redirect("");

