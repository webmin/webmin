#!/usr/local/bin/perl
# save_files.cgi
# Save global files options
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in, %config);

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'files_ecannot'});
&error_setup($text{'files_err'});
&ReadParse();

&lock_file(&make_chroot($config{'named_conf'}));
my $conf = &get_config();
my $options = &find("options", $conf);
&save_opt("statistics-file", \&file_check, $options, 1);
&save_opt("dump-file", \&file_check, $options, 1);
&save_opt("pid-file", \&file_check, $options, 1);
&save_opt("named-xfer", \&file_check, $options, 1);
&flush_file_lines();
&unlock_file(&make_chroot($config{'named_conf'}));
&webmin_log("files", undef, undef, \%in);
&redirect("");

sub file_check
{
return $_[0] =~ /\S/ ? '' : $text{'files_efile'};
}

