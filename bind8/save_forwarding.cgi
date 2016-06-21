#!/usr/local/bin/perl
# save_forwarding.cgi
# Save global forwarding options
use strict;
use warnings;
our (%access, %text, %config, %in);

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'forwarding_ecannot'});
&error_setup($text{'forwarding_err'});
&ReadParse();

&lock_file(&make_chroot($config{'named_conf'}));
my $conf = &get_config();
my $options = &find("options", $conf);
&save_forwarders('forwarders', $options, 1);
&save_choice('forward', $options, 1);
&save_opt('max-transfer-time-in', \&check_mins, $options, 1);
&save_choice('transfer-format', $options, 1);
&save_opt('transfers-in', \&check_trans, $options, 1);
&save_opt('transfers-per-ns', \&check_trans, $options, 1);
&save_opt('transfers-out', \&check_trans, $options, 1);

&flush_file_lines();
&unlock_file(&make_chroot($config{'named_conf'}));
&webmin_log("forwarding", undef, undef, \%in);
&redirect("");

sub check_mins
{
return $_[0] =~ /^\d+$/ ? undef : $text{'forwarding_emins'};
}

sub check_trans
{
return $_[0] =~ /^\d+$/ ? undef : $text{'forwarding_etrans'};
}

