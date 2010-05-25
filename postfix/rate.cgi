#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# A form for SMTP client parameters.
#
# << Here are all options seen in Postfix sample-rate.cf >>

require './postfix-lib.pl';


$access{'rate'} || &error($text{'rate_ecannot'});
&ui_print_header(undef, $text{'rate_title'}, "");

$default = $text{'opts_default'};
$none = $text{'opts_none'};
$no_ = $text{'opts_no'};

# Form start
print &ui_form_start("save_opts.cgi");
print &ui_hidden("_log_form", "rate");
print &ui_table_start($text{'rate_title'}, "width=100%", 4);

&option_freefield("default_destination_concurrency_limit", 15);
&option_freefield("default_destination_recipient_limit", 15);

&option_freefield("initial_destination_concurrency", 15);
&option_freefield("maximal_queue_lifetime", 15);

&option_freefield("minimal_backoff_time", 15);
&option_freefield("maximal_backoff_time", 15);

&option_freefield("queue_run_delay", 15);
&option_freefield("defer_transports", 15);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'opts_save'} ] ]);

&ui_print_footer("", $text{'index_return'});




