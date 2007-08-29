#!/usr/local/bin/perl
# Save SMTP authentication options

require './postfix-lib.pl';

&ReadParse();

$access{'sasl'} || &error($text{'opts_ecannot'});

&error_setup($text{'sasl_err'});

# Validate SASL options
if ($in{'smtpd_tls_key_file_def'} eq "__USE_FREE_FIELD__") {
	-r $in{'smtpd_tls_key_file'} || &error($text{'sasl_ekey'});
	}
if ($in{'smtpd_tls_cert_file_def'} eq "__USE_FREE_FIELD__") {
	-r $in{'smtpd_tls_cert_file'} || &error($text{'sasl_ecert'});
	}
if ($in{'smtpd_tls_CAfile_def'} eq "__USE_FREE_FIELD__") {
	-r $in{'smtpd_tls_CAfile'} || &error($text{'sasl_eca'});
	}

&lock_postfix_files();
&save_options(\%in);

# Save security options
@opts = split(/\0/, $in{'sasl_opts'});
&set_current_value("smtpd_sasl_security_options", join(" ", @opts));

# Save relay options that we care about
@recip = split(/[\s,]+/, &get_current_value("smtpd_recipient_restrictions"));
%newrecip = map { $_, 1 } split(/\0/, $in{'sasl_recip'});
foreach $o ("permit_mynetworks",
	    "permit_inet_interfaces",
	    "reject_unknown_reverse_client_hostname",
	    "permit_sasl_authenticated",
	    "reject_unauth_destination") {
	if ($newrecip{$o}) {
		push(@recip, $o);
		}
	else {
		@recip = grep { $_ ne $o } @recip;
		}
	}
&set_current_value("smtpd_recipient_restrictions", join(" ", &unique(@recip)));

&unlock_postfix_files();

&reload_postfix();

&webmin_log("sasl");
&redirect("");



