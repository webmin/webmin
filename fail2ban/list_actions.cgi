#!/usr/local/bin/perl
# Show a list of all defined actions

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './fail2ban-lib.pl';
our (%in, %text);

&ui_print_header(undef, $text{'actions_title'}, "");

my @actions = &list_actions();
print &ui_form_start("delete_actions.cgi", "post");
my @links = ( &select_all_link("d"),
	      &select_invert_link("d"),
	      &ui_link("edit_action.cgi?new=1", $text{'actions_add'}) );
my @tds = ( "width=5" );
print &ui_links_row(\@links);
print &ui_columns_start([ "",
			  $text{'actions_name'},
			  $text{'actions_ban'} ]);
foreach my $f (@actions) {
	my ($def) = grep { $_->{'name'} eq 'Definition' } @$f;
	next if (!$def);
	my $ban = &find_value("actionban", $def);
	my $fname = &filename_to_name($def->{'file'});
	if (length($ban) > 80) {
		$ban = substr($ban, 0, 80)." ...";
		}
	print &ui_checked_columns_row([
		&ui_link("edit_action.cgi?file=".&urlize($def->{'file'}),
			 $fname),
		&html_escape($ban),
		], \@tds, "d", $def->{'file'});
	}
print &ui_columns_end();
print &ui_links_row(\@links);
print &ui_form_end([ [ undef, $text{'actions_delete'} ] ]);

&ui_print_footer("", $text{'index_return'});
