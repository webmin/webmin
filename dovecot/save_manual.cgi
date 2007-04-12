#!/usr/local/bin/perl
# Update the manually edited config file

require './dovecot-lib.pl';
&ReadParseMime();
&error_setup($text{'manual_err'});

$in{'data'} =~ s/\r//g;
$in{'data'} =~ /\S/ || &error($text{'manual_edata'});

&open_lock_tempfile(DATA, ">$config{'dovecot_config'}");
&print_tempfile(DATA, $in{'data'});
&close_tempfile(DATA);

&webmin_log("manual", undef, $config{'dovecot_config'});
&redirect("");

