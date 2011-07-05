#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# A form for SMTP server parameters.
# modified by Roberto Tecchio, 2005 (www.tecchio.net)
#
# << Here are all options seen in Postfix sample-smtpd.cf >>

require './postfix-lib.pl';

$access{'smtpd'} || &error($text{'smtpd_ecannot'});
&ui_print_header(undef, $text{'smtpd_title'}, "");

$default = $text{'opts_default'};
$none = $text{'opts_none'};
$no_ = $text{'opts_no'};

# Form start
print &ui_form_start("save_opts.cgi");
print &ui_hidden("_log_form", "smtpd");
print &ui_table_start($text{'smtpd_title'}, "width=100%", 4);

&option_radios_freefield("smtpd_banner", 65, $default);

&option_freefield("smtpd_recipient_limit", 15);
&option_yesno("disable_vrfy_command", 'help');

&option_freefield("smtpd_timeout", 15);
&option_freefield("smtpd_error_sleep_time", 15);

&option_freefield("smtpd_soft_error_limit", 15);
&option_freefield("smtpd_hard_error_limit", 15);

&option_yesno("smtpd_helo_required", 'help');
&option_yesno("allow_untrusted_routing", 'help');

&option_radios_freefield("smtpd_etrn_restrictions", 65, $default);

&option_radios_freefield("smtpd_helo_restrictions", 65, $default);

&option_radios_freefield("smtpd_sender_restrictions", 65, $default);

&option_radios_freefield("smtpd_recipient_restrictions", 65, $default);

&option_radios_freefield("relay_domains", 65, $default);

&option_mapfield("relay_recipient_maps", 60);

&option_freefield("access_map_reject_code", 15, $default);
&option_freefield("invalid_hostname_reject_code", 15, $default);

&option_freefield("maps_rbl_reject_code", 15, $default);
&option_freefield("reject_code", 15, $default);

&option_freefield("relay_domains_reject_code", 15, $default);
&option_freefield("unknown_address_reject_code", 15, $default);

&option_freefield("unknown_client_reject_code", 15, $default);
&option_freefield("unknown_hostname_reject_code", 15, $default);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'opts_save'} ] ]);

# Current relay map contents
print &ui_hr();
if (&get_real_value("relay_recipient_maps") eq "")
{
    print ($text{'smtpd_nomap'}."<br><br>");
}
else
{
    &generate_map_edit("relay_recipient_maps", $text{'map_click'}." ".
	       &hlink($text{'help_map_format'}, "relay_recipient_maps"));
}

&ui_print_footer("", $text{'index_return'});
   
