#!/usr/local/bin/perl
# save_misc.cgi
# Save global miscellaneous options
use strict;
use warnings;
our (%access, %text, %in, %config);

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'misc_ecannot'});
&error_setup($text{'misc_err'});
&ReadParse();

&lock_file(&make_chroot($config{'named_conf'}));
my $conf = &get_config();
my $options = &find("options", $conf);
&save_opt("coresize", \&size_check, $options, 1);
&save_opt("datasize", \&size_check, $options, 1);
&save_opt("files", \&files_check, $options, 1);
&save_opt("stacksize", \&size_check, $options, 1);
&save_opt("cleaning-interval", \&mins_check, $options, 1);
&save_opt("interface-interval", \&mins_check, $options, 1);
&save_opt("statistics-interval", \&mins_check, $options, 1);
&save_choice("recursion", $options, 1);
&save_choice("multiple-cnames", $options, 1);
&save_choice("fetch-glue", $options, 1);
&save_choice("auth-nxdomain", $options, 1);

&flush_file_lines();
&unlock_file(&make_chroot($config{'named_conf'}));
&webmin_log("misc", undef, undef, \%in);
&redirect("");

sub size_check
{
return $_[0] =~ /^\d+[kmg]*$/i ? "" : $text{'misc_esize'};
}

sub files_check
{
return $_[0] =~ /^\d+$/i ? "" : $text{'misc_efiles'};
}

sub mins_check
{
return $_[0] =~ /^\d+$/i ? "" : $text{'misc_emins'};
}

