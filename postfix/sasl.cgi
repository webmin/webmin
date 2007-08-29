#!/usr/local/bin/perl
# Show SMTP authentication related paramters

require './postfix-lib.pl';

$access{'sasl'} || &error($text{'sasl_ecannot'});
&ui_print_header(undef, $text{'sasl_title'}, "");

$default = $text{'opts_default'};
$none = $text{'opts_none'};
$no_ = $text{'opts_no'};

print "<form action=save_sasl.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'sasl_title'}</b></td></tr>\n";
print "<tr $cb> <td><table width=100%>\n";

# Enabled, accept broken clients
print "<tr>\n";
&option_yesno("smtpd_sasl_auth_enable");
&option_yesno("broken_sasl_auth_clients");
print "</tr>\n";

# Anonymous and plain-text options
print "<tr>\n";
%opts = map { $_, 1 }
	    split(/[\s,]+/, &get_current_value("smtpd_sasl_security_options"));
print "<td valign=top>","<b>$text{'sasl_opts'}</b>",
      "</td> <td colspan=3 nowrap>\n";
foreach $o ("noanonymous", "noplaintext") {
	print &ui_checkbox("sasl_opts", $o, $text{'sasl_'.$o}, $opts{$o}),
	      "<br>\n";
	}
print "</td> </tr>\n";

# SASL-related relay restrictions
%recip = map { $_, 1 }
	    split(/[\s,]+/, &get_current_value("smtpd_recipient_restrictions"));
print "<td valign=top>","<b>$text{'sasl_recip'}</b>",
      "</td> <td colspan=3 nowrap>\n";
foreach $o ("permit_mynetworks",
	    "permit_inet_interfaces",
	    "reject_unknown_reverse_client_hostname",
	    "permit_sasl_authenticated",
	    "reject_unauth_destination") {
	print &ui_checkbox("sasl_recip", $o, $text{'sasl_'.$o}, $recip{$o}),
	      "<br>\n";
	}
print "</td> </tr>\n";

# Delay bad logins
print "<tr>\n";
&option_yesno("smtpd_delay_reject");
print "</tr>\n";

#smtpd_recipient_restrictions

print "</table></td></tr></table><p>\n";
print "<input type=submit value=\"$text{'opts_save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});
