#!/usr/local/bin/perl
# Show networking-related options

require './frox-lib.pl';
&ui_print_header(undef, $text{'net_title'}, "");
$conf = &get_config();

print &ui_form_start("save_net.cgi", "post");
print &ui_table_start($text{'net_header'}, "width=100%", 4);

print &config_opt_textbox($conf, "Listen", 40, 3, $text{'net_all'});

print &config_textbox($conf, "Port", 6);

print &config_opt_textbox($conf, "BindToDevice", 6, 1, $text{'net_all'});

print &config_yesno($conf, "FromInetd", undef, undef, "no");

print &config_exists($conf, "NoDetach", $text{'net_fg'}, $text{'net_bg'});

print &config_opt_textbox($conf, "FTPProxy", 30, 3, $text{'net_none'});

print &config_opt_textbox($conf, "TcpOutgoingAddr", 20, 3);

print &config_opt_textbox($conf, "PASVAddress", 20, 3);

print &config_opt_textbox($conf, "ResolvLoadHack", 40, 3, $text{'net_none'});

print &ui_table_end();
print &ui_form_end([ [ 'save', $text{'save'} ] ], "100%");

&ui_print_footer("", $text{'index_return'});

