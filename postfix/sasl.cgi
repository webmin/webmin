#!/usr/local/bin/perl
# Show SMTP authentication related parameters

require './postfix-lib.pl';

$access{'sasl'} || &error($text{'sasl_ecannot'});
&ui_print_header(undef, $text{'sasl_title'}, "");

$default = $text{'opts_default'};
$none = $text{'opts_none'};
$no_ = $text{'opts_no'};

# Form start
print &ui_form_start("save_sasl.cgi");
print &ui_table_start($text{'sasl_title'}, "width=100%", 2);

# Enabled, accept broken clients
&option_yesno("smtpd_sasl_auth_enable");
&option_yesno("smtpd_tls_auth_only");
&option_yesno("broken_sasl_auth_clients");

# Anonymous and plain-text options
%opts = map { $_, 1 }
	    split(/[\s,]+/, &get_current_value("smtpd_sasl_security_options"));
@cbs = ( );
foreach $o ("noanonymous", "noplaintext", "noactive", "nodictionary", "forward_secrecy") {
	push(@cbs, &ui_checkbox("sasl_opts", $o, $text{'sasl_'.$o}, $opts{$o}));
	}
print &ui_table_row($text{'sasl_opts'}, join("<br>\n", @cbs), 3);

# SASL-related recipient restrictions
%recip = map { $_, 1 }
	    split(/[\s,]+/, &get_current_value("smtpd_recipient_restrictions"));
@cbs = ( );
foreach $o (&list_smtpd_restrictions()) {
	push(@cbs, &ui_checkbox("sasl_recip", $o, $text{'sasl_'.$o},
				$recip{$o}));
	}
print &ui_table_row($text{'sasl_recip'}, join("<br>\n", @cbs), 3);

# SASL-relayed relay restrictions
%relay = map { $_, 1 }
	    split(/[\s,]+/, &get_current_value("smtpd_relay_restrictions"));
@cbs = ( );
foreach $o (&list_smtpd_restrictions()) {
	push(@cbs, &ui_checkbox("sasl_relay", $o, $text{'sasl_'.$o},
				$relay{$o}));
	}
print &ui_table_row($text{'sasl_relay'}, join("<br>\n", @cbs), 3);

# Delay bad logins
&option_yesno("smtpd_delay_reject");

print &ui_table_hr();

# SMTP TLS options
if (&compare_version_numbers($postfix_version, 2.3) >= 0) {
	$level = &get_current_value("smtpd_tls_security_level");
	print &ui_table_row($text{'opts_smtpd_use_tls'},
		&ui_select("smtpd_tls_security_level", $level, 
			   [ [ "", $text{'default'} ],
			     [ "none", $text{'sasl_level_none'} ],
			     [ "may", $text{'sasl_level_may'} ],
			     [ "encrypt", $text{'sasl_level_encrypt'} ] ]));
	}
else {
	&option_yesno("smtpd_use_tls");
	}

&option_radios_freefield("smtpd_tls_cert_file", 60, $none);

&option_radios_freefield("smtpd_tls_key_file", 60, $none);

&option_radios_freefield("smtpd_tls_CAfile", 60, $none);

print &ui_table_hr();

# Outgoing authentication options
&option_radios_freefield("relayhost", 45, $text{'opts_direct'});

# Use SASL for outgoing authentication?
&option_yesno("smtp_sasl_auth_enable");

# Get the current map value for the relayhost
$rh = &get_current_value("relayhost");
$rh =~ s/^\[(.*)\]$/$1/g;
if ($rh) {
	$pmap = &get_maps("smtp_sasl_password_maps");
	foreach my $o (@$pmap) {
		if ($o->{'name'} eq $rh) {
			($ruser, $rpass) = split(/:/, $o->{'value'}, 2);
			}
		}
	}
print &ui_table_row($text{'sasl_login'},
	&ui_radio("login_none", $ruser ? 0 : 1,
		  [ [ 1, $text{'sasl_nologin'}."<br>" ],
		    [ 0, &text('sasl_userpass',
				&ui_textbox("login_user", $ruser, 20), 
				&ui_textbox("login_pass", $rpass, 20)) ] ]), 3);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'opts_save'} ] ]);

&ui_print_footer("", $text{'index_return'});
