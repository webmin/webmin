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

# Validate remote mail server login
if (!$in{'login_none'}) {
	$in{'login_user'} =~ /^[^: ]+$/ || &error($text{'sasl_elogin'});
	$in{'login_pass'} =~ /^[^: ]*$/ || &error($text{'sasl_epass'});
	}

&lock_postfix_files();
&save_options(\%in);

# Save security options
@opts = split(/\0/, $in{'sasl_opts'});
&set_current_value("smtpd_sasl_security_options", join(" ", @opts));

# Save recipient options that we care about
@recip = split(/[\s,]+/, &get_current_value("smtpd_recipient_restrictions"));
%newrecip = map { $_, 1 } split(/\0/, $in{'sasl_recip'});
foreach $o (&list_smtpd_restrictions()) {
	if ($newrecip{$o}) {
		push(@recip, $o) if (&indexof($o, @recip) < 0);
		}
	else {
		@recip = grep { $_ ne $o } @recip;
		}
	}
&set_current_value("smtpd_recipient_restrictions", join(" ", @recip));

# Save relay options that we care about
@relay = split(/[\s,]+/, &get_current_value("smtpd_relay_restrictions"));
%newrelay = map { $_, 1 } split(/\0/, $in{'sasl_relay'});
foreach $o (&list_smtpd_restrictions()) {
	if ($newrelay{$o}) {
		push(@relay, $o) if (&indexof($o, @relay) < 0);
		}
	else {
		@relay = grep { $_ ne $o } @relay;
		}
	}
&set_current_value("smtpd_relay_restrictions", join(" ", @relay));

# Save SSL options
if (&compare_version_numbers($postfix_version, 2.3) >= 0) {
	&set_current_value("smtpd_tls_security_level",
			   $in{'smtpd_tls_security_level'});
	}

# Save SMTP relay options
$rh = &get_current_value("relayhost");
$rh =~ s/^\[(.*)\]$/$1/g;
if ($rh) {
	if ($in{'login_none'} == 0 &&
	    !&get_current_value("smtp_sasl_password_maps")) {
		# Setup initial map
		&set_current_value("smtp_sasl_password_maps",
				"hash:".&guess_config_dir()."/smtp_sasl_password_map");
		}
        $pmap = &get_maps("smtp_sasl_password_maps");
	foreach my $o (@$pmap) {
                if ($o->{'name'} eq $rh) {
			$old = $o;
			}
		}
	$newmap = { 'name' => $rh,
		    'value' => $in{'login_user'}.":".$in{'login_pass'} };
	if ($old && $in{'login_def'}) {
		# Delete entry
		&delete_mapping("smtp_sasl_password_maps", $old);
		}
	elsif ($old && !$in{'login_def'}) {
		# Update entry
		&modify_mapping("smtp_sasl_password_maps", $old, $newmap);
		}
	elsif (!$old && !$in{'login_def'}) {
		# Add entry
		&create_mapping("smtp_sasl_password_maps", $newmap);
		}
	&regenerate_any_table("smtp_sasl_password_maps");
	}

&unlock_postfix_files();

$err = &reload_postfix();
&error($err) if ($err);

&webmin_log("sasl");
&redirect("");



