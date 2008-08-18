#!/usr/local/bin/perl
# edit_host.cgi
# Edit or create a host address

require './net-lib.pl';
$access{'hosts'} == 2 || &error($text{'hosts_ecannot'});
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'hosts_create'}, "");
	}
else {
	&ui_print_header(undef, $text{'hosts_edit'}, "");
	@hosts = &list_hosts();
	$h = $hosts[$in{'idx'}];
	}

# Start of the form
print &ui_form_start("save_host.cgi");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});
print &ui_table_start($text{'hosts_detail'}, undef, 2);

# IP address
print &ui_table_row($text{'hosts_ip'},
	&ui_textbox("address", $h->{'address'}, 30));

# Hostnames
print &ui_table_row($text{'hosts_host'},
	&ui_textarea("hosts", join("\n", @{$h->{'hosts'}}), 5, 50));

# End of the form
print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}

&ui_print_footer("list_hosts.cgi", $text{'hosts_return'});

