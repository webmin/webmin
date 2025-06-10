#!/usr/local/bin/perl
# Update the manually edited config file

require './dovecot-lib.pl';
&ReadParseMime();
&error_setup($text{'manual_err'});
$conf = &get_config();
@files = &unique(map { $_->{'file'} } @$conf);
&indexof($in{'file'}, @files) >= 0 || &error($text{'manual_efile'});

$in{'data'} =~ s/\r//g;
$in{'data'} =~ /\S/ || &error($text{'manual_edata'});

&open_lock_tempfile(DATA, ">$in{'file'}");
&print_tempfile(DATA, $in{'data'});
&close_tempfile(DATA);

&webmin_log("manual", undef, $in{'file'});
&redirect("");

