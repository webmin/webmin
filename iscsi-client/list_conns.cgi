#!/usr/local/bin/perl
# Display all active connections, with an option to add a new one

use strict;
use warnings;
require './iscsi-client-lib.pl';
our (%text);

&ui_print_header(undef, $text{'conns_title'}, "");

my @conns = &list_iscsi_connections();
if (@conns) {
	# Show current connections
	# XXX devices?
	my @tds = ( "width=5" );
	print &ui_form_start("delete_conns.cgi");
	print &ui_columns_start(
		[ "", $text{'conns_ip'}, $text{'conns_sport'},
		      $text{'conns_name'}, $text{'conns_target'},
		      $text{'conns_device'} ],
		100, 0, \@tds);
	foreach my $c (@conns) {
		print &ui_checked_columns_row([
			$c->{'ip'}, $c->{'port'},
			$c->{'name'}, $c->{'target'},
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
# XXX targets are on next page
print &ui_form_start("add_conn.cgi", "post");
print &ui_table_start($text{'conns_header'}, undef, 2);

# Server hostname or IP
print &ui_table_row($text{'conns_host'},
	&ui_textbox("host", undef, 40));

# Server port
print &ui_table_row($text{'conns_port'},
	&ui_opt_textbox("port", undef, 5, $text{'default'}." (3260)"));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'conns_start'} ] ]);

&ui_print_footer("", $text{'index_return'});
