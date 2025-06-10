#!/usr/local/bin/perl
# edit_vserv.cgi
# Edit <VirtualHost> section details

require './proftpd-lib.pl';
&ReadParse();
$vconf = &get_config()->[$in{'virt'}];
$desc = &text('virt_header1', $vconf->{'value'});
&ui_print_header($desc, $text{'vserv_title'}, "",
	undef, undef, undef, undef, &restart_button());

$name = &find_directive("ServerName", $vconf->{'members'});
$port = &find_directive("Port", $vconf->{'members'});

print &ui_form_start("save_vserv.cgi", "post");
print &ui_hidden("virt", $in{'virt'});
print &ui_table_start($text{'vserv_title'}, undef, 2);

print &ui_table_row($text{'vserv_addr'},
	&ui_textbox("addr", $vconf->{'value'}, 30));

print &ui_table_row($text{'vserv_name'},
	&opt_input($name, "ServerName", $text{'default'}, 30));

print &ui_table_row($text{'vserv_port'},
	&opt_input($port, "Port", $text{'default'}, 6));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ],
		     [ 'delete', $text{'vserv_delete'} ] ]);

&ui_print_footer("virt_index.cgi?virt=$in{'virt'}", $text{'virt_return'},
	"", $text{'index_return'});

