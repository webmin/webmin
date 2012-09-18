#!/usr/local/bin/perl
# Display all known interfaces

use strict;
use warnings;
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
		[ "", $text{'ifaces_name'}, $text{'ifaces_uses'} ],
		100, 0, \@tds);
	foreach my $c (@$ifaces) {
		my $uses = join(" | ", map { &text('ifaces_on', $_->{'target'}, $_->{'ip'}) } @{$c->{'targets'}});
		print &ui_checked_columns_row([
			$c->{'name'},
			$uses || "<i>$text{'ifaces_nouses'}</i>",
			], \@tds, "d", $c->{'name'});
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

# XXX??

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'create'} ] ]);

&ui_print_footer("", $text{'index_return'});
