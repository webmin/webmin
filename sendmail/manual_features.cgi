#!/usr/local/bin/perl
# manual_features.cgi
# Save the manually edited M4 file

require './sendmail-lib.pl';
require './features-lib.pl';
&ReadParseMime();
$features_access || &error($text{'features_ecannot'});

$in{'data'} =~ s/\r//g;
$in{'data'} =~ s/\n*$/\n/;
&open_tempfile(FEAT, ">$config{'sendmail_mc'}");
&print_tempfile(FEAT, $in{'data'});
&close_tempfile(FEAT);
&redirect("list_features.cgi");

