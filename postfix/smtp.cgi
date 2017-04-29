#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# A form for SMTP client parameters.
#
# << Here are all options seen in Postfix sample-smtp.cf >>

require './postfix-lib.pl';


$access{'smtp'} || &error($text{'smtp_ecannot'});
&ui_print_header(undef, $text{'smtp_title'}, "");

$default = $text{'opts_default'};
$none = $text{'opts_none'};
$no_ = $text{'opts_no'};

# Start of form
print &ui_form_start("save_opts.cgi");
print &ui_hidden("_log_form", "smtp");
print &ui_table_start($text{'smtp_title'}, "width=100%", 4);

&option_radios_freefield("best_mx_transport", 25, $text{'opts_best_mx_transport_default'});

&option_radios_freefield("fallback_relay", 60, $default);

&option_yesno("ignore_mx_lookup_error", 'help');
if (&compare_version_numbers($postfix_version, 2) <= 0) {
	&option_yesno("smtp_skip_4xx_greeting", 'help');
	}

&option_yesno("smtp_skip_quit_response", 'help');

&option_radios_freefield("smtp_destination_concurrency_limit", 15, $default);

&option_radios_freefield("smtp_destination_recipient_limit", 15, $default);

&option_freefield("smtp_connect_timeout", 15);
&option_freefield("smtp_helo_timeout", 15);

&option_freefield("smtp_mail_timeout", 15);
&option_freefield("smtp_rcpt_timeout", 15);

&option_freefield("smtp_data_init_timeout", 15);
&option_freefield("smtp_data_xfer_timeout", 15);

&option_freefield("smtp_data_done_timeout", 15);
&option_freefield("smtp_quit_timeout", 15);

&option_yesno("smtp_use_tls");
&option_freefield("smtp_sasl_security_options", 60);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'opts_save'} ] ]);

&ui_print_footer("", $text{'index_return'});

