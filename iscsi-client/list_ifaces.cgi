#!/usr/local/bin/perl
# Display all known interfaces

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-client-lib.pl';
our (%text);

&ui_print_header(undef, $text{'ifaces_title'}, "");

my $ifaces = &list_iscsi_ifaces();
ref($ifaces) || &error(&text('ifaces_elist', $ifaces));
if (@$ifaces) {
	# Show current connections
	my @tds = ( "width=5" );
	print &ui_form_start("delete_ifaces.cgi");
	print &ui_columns_start(
		[ "", $text{'ifaces_name'}, $text{'ifaces_transport'},
		  $text{'ifaces_ifacename'}, $text{'ifaces_ipaddress'},
		  $text{'ifaces_uses'} ],
		100, 0, \@tds);
	foreach my $c (@$ifaces) {
		my $uses = join(" | ", map { &text('ifaces_on', $_->{'target'}, $_->{'ip'}) } @{$c->{'targets'}});
		print &ui_checked_columns_row([
			$c->{'name'},
			uc($c->{'iface.transport_name'}),
			$c->{'iface.net_ifacename'} ||
				"<i>$text{'ifaces_notset'}</i>",
			$c->{'iface.ipaddress'} ||
				"<i>$text{'ifaces_notset'}</i>",
			$uses || "<i>$text{'ifaces_nouses'}</i>",
			], \@tds, "d", $c->{'name'}, 0, $c->{'builtin'});
		}
	print &ui_columns_end();
	print &ui_form_end([ [ undef, $text{'ifaces_delete'} ] ]);
	}
else {
	print "<b>$text{'ifaces_none'}</b><p>\n";
	}

# Show form to add
print &ui_form_start("add_iface.cgi", "post");
print &ui_table_start($text{'ifaces_header'}, undef, 2);

# Interface name
print &ui_table_row($text{'ifaces_name'},
	&ui_textbox("name", undef, 40));

# Transport type
print &ui_table_row($text{'ifaces_transport'},
	&ui_select("transport", "tcp",
		   [ [ "tcp", "TCP" ],
		     [ "iser", "ISER" ],
		     [ "cxgb3i", "Chelsio CXGB3I" ],
		     [ "bnx2i", "Broadcom BNX2I" ],
		     [ "be2iscsi", "ServerEngines BE2ISCSI" ] ]));

# Source IP address
print &ui_table_row($text{'ifaces_ipaddress'},
	&ui_opt_textbox("ipaddress", undef, 20, $text{'ifaces_ipaddressdef'}));

# MAC address
print &ui_table_row($text{'ifaces_hwaddress'},
	&ui_opt_textbox("hwaddress", undef, 30, $text{'ifaces_ipaddressdef'}));

# Source interface
my @active;
if (&foreign_check("net")) {
	&foreign_require("net");
	@active = grep { $_->{'name'} ne 'lo' } &net::active_interfaces();
	}
if (@active) {
	print &ui_table_row($text{'ifaces_ifacename'},
		&ui_select("ifacename", undef,
			   [ [ '', "&lt;$text{'ifaces_ipaddressdef'}&gt;" ],
			     map { $_->{'fullname'} }
				 grep { $_->{'virtual'} eq '' } @active ]));
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'create'} ] ]);

&ui_print_footer("", $text{'index_return'});
