#!/usr/local/bin/perl
# Show FTP protocol options

require './frox-lib.pl';
&ui_print_header(undef, $text{'ftp_title'}, "");
$conf = &get_config();

print &ui_form_start("save_ftp.cgi", "post");
print &ui_table_start($text{'ftp_header'}, "width=100%", 4);

print &config_yesno($conf, "APConv", undef, undef, "no");

print &config_yesno($conf, "PAConv", undef, undef, "no");

print &config_yesno($conf, "BounceDefend", undef, undef, "yes");

print &config_yesno($conf, "SameAddress", undef, undef, "yes");

print &config_yesno($conf, "AllowNonASCII", undef, undef, "no");

print &config_yesno($conf, "TransparentData", undef, undef, "no");

print &config_opt_range($conf, "ControlPorts", 3);

print &config_opt_range($conf, "PassivePorts", 3);

print &config_opt_range($conf, "ActivePorts", 3);

print &ui_table_end();
print &ui_form_end([ [ 'save', $text{'save'} ] ], "100%");

&ui_print_footer("", $text{'index_return'});

