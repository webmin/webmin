#!/usr/local/bin/perl
# Display all active connections, with an option to add a new one

use strict;
use warnings;
require './iscsi-client-lib.pl';
our (%text);

&ui_print_header(undef, $text{'conns_title'}, "");

my $conns = &list_iscsi_connections();
ref($conns) || &error(&text('conns_elist', $conns));
if (@$conns) {
	# Show current connections
	my @tds = ( "width=5" );
	print &ui_form_start("delete_conns.cgi");
	print &ui_columns_start(
		[ "", $text{'conns_ip'}, $text{'conns_sport'},
		      $text{'conns_name'}, $text{'conns_target'},
		      $text{'conns_username'}, $text{'conns_device'} ],
		100, 0, \@tds);
	foreach my $c (@$conns) {
		print &ui_checked_columns_row([
			"<a href='view_conn.cgi?num=$c->{'num'}'>".
			  $c->{'ip'}."</a>",
			$c->{'port'}, $c->{'name'}, $c->{'target'},
			$c->{'username'} || "<i>$text{'conns_nouser'}</i>",
			$c->{'device'},
			], \@tds, "d", $c->{'num'});
		}
	print &ui_columns_end();
	print &ui_form_end([ [ undef, $text{'conns_delete'} ] ]);
	}
else {
	print "<b>$text{'conns_none'}</b><p>\n";
	}

# Show form to add
print &ui_form_start("add_form.cgi", "post");
print &ui_table_start($text{'conns_header'}, undef, 2);

# Server hostname or IP
print &ui_table_row($text{'conns_host'},
	&ui_textbox("host", undef, 40));

# Server port
print &ui_table_row($text{'conns_port'},
	&ui_opt_textbox("port", undef, 5, $text{'default'}." (3260)"));

# Interface to use
my $ifaces = &list_iscsi_ifaces();
if (ref($ifaces)) {
	print &ui_table_row($text{'conns_iface'},
		&ui_select("iface", undef,
			   [ [ undef, "&lt;".$text{'conns_ifacedef'}."&gt;" ],
			     map { $_->{'name'} } @$ifaces ]));
	}
else {
	print &ui_table_row($text{'conns_iface'},
			    &text('conns_ifaceerr', $ifaces));
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'conns_start'} ] ]);

&ui_print_footer("", $text{'index_return'});
