#!/usr/local/bin/perl
# save_opts.cgi
# Save global QMail options

require './qmail-lib.pl';
&ReadParse();
&error_setup($text{'opts_err'});

# Validate inputs
$in{'me'} =~ /^[A-Za-z0-9\.\-]+$/ ||
	&error($text{'opts_eme'});
$in{'helo_def'} || $in{'helo'} =~ /^[A-Za-z0-9\.\-]+$/ ||
	&error($text{'opts_ehelo'});
$in{'toconnect_def'} || $in{'toconnect'} =~ /^\d+$/ ||
	&error($text{'opts_etoconnect'});
$in{'toremote_def'} || $in{'toremote'} =~ /^\d+$/ ||
	&error($text{'opts_etoremote'});
$in{'bytes_def'} || $in{'bytes'} =~ /^\d+$/ ||
	&error($text{'opts_ebytes'});
$in{'timeout_def'} || $in{'timeout'} =~ /^\d+$/ ||
	&error($text{'opts_etimeout'});
$in{'localip_def'} || $in{'localip'} =~ /^[A-Za-z0-9\.\-]+$/ ||
	&error($text{'opts_elocalip'});

# Update config files
&set_control_file("me", $in{'me'});
&set_control_file("helohost", $in{'helo_def'} ? undef : $in{'helo'});
&set_control_file("timeoutconnect", $in{'toconnect_def'} ? undef
							 : $in{'toconnect'});
&set_control_file("timeoutremote", $in{'toremote_def'} ? undef
						       : $in{'toremote'});
&set_control_file("timeoutconnect", $in{'toconnect_def'} ? undef
							 : $in{'toconnect'});
&set_control_file("databytes", $in{'bytes_def'} ? undef : $in{'bytes'});
&set_control_file("timeoutsmtpd", $in{'timeout_def'} ? undef
						     : $in{'timeout'});
&set_control_file("localiphost", $in{'localip_def'} ? undef : $in{'localip'});
&set_control_file("smtpgreeting", $in{'greet_def'} ? undef : $in{'greet'});

&webmin_log("opts", undef, undef, \%in);
&redirect("");

