#!/usr/local/bin/perl
# edit_ipnode.cgi
# Edit or create a ipnode address

require './net-lib.pl';
$access{'ipnodes'} == 2 || &error($text{'ipnodes_ecannot'});
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'ipnodes_create'}, "");
	}
else {
	&ui_print_header(undef, $text{'ipnodes_edit'}, "");
	@ipnodes = &list_ipnodes();
	$h = $ipnodes[$in{'idx'}];
	}

# Form start
print &ui_form_start("save_ipnode.cgi");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});
print &ui_table_start($text{'ipnodes_detail'}, undef, 2);

# IPv6 address
print &ui_table_row($text{'ipnodes_ip'},
	&ui_textbox("address", $h->{'address'}, 30));

# Hostnames for address
print &ui_table_row($text{'ipnodes_host'},
	&ui_textarea("ipnodes", join("\n", @{$h->{'ipnodes'}}), 5, 50));

# End of the form
print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}

&ui_print_footer("list_ipnodes.cgi", $text{'ipnodes_return'});

