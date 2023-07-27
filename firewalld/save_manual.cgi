#!/usr/local/bin/perl
# Update the manually edited FirewallD config file

require './firewalld-lib.pl';
&ReadParseMime();
&error_setup($text{'manual_err'});
my @files = &unique(&get_config_files());
my $file = $in{'file'};
&indexof($file, @files) >= 0 || &error($text{'manual_efile'});

$in{'data'} =~ s/\r//g;

&open_lock_tempfile(my $data, ">$file");
&print_tempfile($data, $in{'data'});
&close_tempfile($data);

&webmin_log("manual", undef, $file);
&redirect("");

