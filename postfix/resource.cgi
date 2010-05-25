#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# A form for controlling resource control.
#
# << Here are all options seen in Postfix sample-resource.cf >>

require './postfix-lib.pl';


$access{'resource'} || &error($text{'resource_ecannot'});
&ui_print_header(undef, $text{'resource_title'}, "");

$default = $text{'opts_default'};
$none = $text{'opts_none'};
$no_ = $text{'opts_no'};

# Form start
print &ui_form_start("save_opts.cgi");
print &ui_hidden("_log_form", "resource");
print &ui_table_start($text{'resource_title'}, "width=100%", 4);

&option_freefield("bounce_size_limit", 15);
&option_freefield("command_time_limit", 15);

&option_freefield("default_process_limit", 15);
&option_freefield("duplicate_filter_limit", 15);

&option_freefield("deliver_lock_attempts", 15);
&option_freefield("deliver_lock_delay", 15);

&option_freefield("fork_attempts", 15);
&option_freefield("fork_delay", 15);

&option_freefield("header_size_limit", 15);
&option_freefield("line_length_limit", 15);

&option_freefield("message_size_limit", 15);
&option_freefield("qmgr_message_active_limit", 15);

&option_freefield("qmgr_message_recipient_limit", 15);
&option_freefield("queue_minfree", 15);

&option_freefield("stale_lock_time", 15);
&option_freefield("transport_retry_time", 15);

&option_freefield("mailbox_size_limit", 15);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'opts_save'} ] ]);

&ui_print_footer("", $text{'index_return'});




