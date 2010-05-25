#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# A form for controlling local delivery.
#
# << Here are all options seen in Postfix sample-local.cf >>

require './postfix-lib.pl';


$access{'local_delivery'} || &error($text{'local_delivery_ecannot'});
&ui_print_header(undef, $text{'local_delivery_title'}, "");

$default = $text{'opts_default'};
$none = $text{'opts_none'};
$no_ = $text{'opts_no'};

# Start of form
print &ui_form_start("save_opts.cgi");
print &ui_hidden("_log_form", "local");
print &ui_table_start($text{'local_delivery_title'}, "width=100%", 4);

&option_radios_freefield("local_transport", 30, $text{'opts_local_transport_local'});

&option_radios_freefield("local_command_shell", 40, $text{'opts_local_command_shell_direct'});

&option_freefield("forward_path", 80);

&option_freefield("allow_mail_to_commands", 40);

&option_freefield("allow_mail_to_files", 40);

&option_freefield("default_privs", 25);

&option_radios_freefield("home_mailbox", 40, $text{'opts_home_mailbox_default'});

&option_radios_freefield("luser_relay", 40, $text{'opts_luser_relay_none'});

&option_freefield("mail_spool_directory", 40);

&option_freefield("mailbox_command", 60, $text{'opts_mailbox_command_none'});

&option_radios_freefield("mailbox_transport", 40, $text{'opts_mailbox_transport_none'});

&option_radios_freefield("fallback_transport", 40, $text{'opts_fallback_transport_none'});

&option_freefield("local_destination_concurrency_limit", 6);

&option_radios_freefield("local_destination_recipient_limit", 40, $text{'opts_local_destination_recipient_limit_default'});

&option_radios_freefield("prepend_delivered_header", 40, $text{'opts_prepend_delivered_header_default'});

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'opts_save'} ] ]);

&ui_print_footer("", $text{'index_return'});




