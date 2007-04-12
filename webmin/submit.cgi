#!/usr/local/bin/perl
# Just submit OS info

require './webmin-lib.pl';
&error_setup($text{'submit_err'});
$config{'submitted'} && &error($text{'submit_edone'});

$err = &submit_os_info();
&error($err) if ($err);

# Say something nice
&ui_print_header(undef, $text{'submit_title'}, "");

print $text{'submit_ok'},"<p>\n";
$config{'submitted'} = &get_webmin_id();
&save_module_config();

&ui_print_footer("", $text{'index_return'});


