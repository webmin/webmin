#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# A form for editing address rewriting for Postfix
#
# << Here are all options seen in Postfix sample-rewrite.cf >>

require './postfix-lib.pl';

$access{'address_rewriting'} || &error($text{'address_rewriting_ecannot'});
&ui_print_header(undef, $text{'address_rewriting_title'}, "");

$default = $text{'opts_default'};
$none = $text{'opts_none'};
$no_ = $text{'opts_no'};

print &ui_form_start("save_opts.cgi");
print &ui_hidden("_log_form", "opts");
print &ui_table_start($text{'address_rewriting_title'}, "width=100%", 4);

&option_yesno("allow_percent_hack");
&option_yesno("append_at_myorigin");

&option_yesno("append_dot_mydomain");
&option_yesno("swap_bangpath", 'help');

&option_radios_freefield("empty_address_recipient", 35, $text{'opt_empty_recip_default'});

&option_radios_freefield("masquerade_domains", 35, $none);

&option_radios_freefield("masquerade_exceptions", 35, $none);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'opts_save'} ] ]);

&ui_print_footer("", $text{'index_return'});




