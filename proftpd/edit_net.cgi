#!/usr/local/bin/perl
# edit_net.cgi
# Display networking options

require './proftpd-lib.pl';
&ui_print_header(undef, $text{'net_title'}, "",
	undef, undef, undef, undef, &restart_button());
$conf = &get_config();

print &ui_form_start("save_net.cgi", "post");
print &ui_table_start($text{'net_header'}, undef, 2);

print &choice_input($text{'net_type'}, 'ServerType', $conf, 'inetd',
		    $text{'net_inetd'}, 'inetd',
		    $text{'net_stand'}, 'standalone');
print &text_input($text{'net_port'}, 'Port', $conf, '21', 6);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

