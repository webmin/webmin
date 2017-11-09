#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# A form for controlling debugging features.
#
# << Here are all options seen in Postfix sample-debug.cf >>

require './postfix-lib.pl';


$access{'debug'} || &error($text{'debug_ecannot'});
&ui_print_header(undef, $text{'debug_title'}, "");

$default = $text{'opts_default'};
$none = $text{'opts_none'};
$no_ = $text{'opts_no'};

# Start of form
print &ui_form_start("save_opts.cgi");
print &ui_hidden("_log_form", "debug");
print &ui_table_start($text{'debug_title'}, "width=100%", 4);

&option_freefield("debug_peer_list", 65);

&option_freefield("debug_peer_level", 15);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'opts_save'} ] ]);

&ui_print_footer("", $text{'index_return'});

