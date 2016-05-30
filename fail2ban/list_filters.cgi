#!/usr/local/bin/perl
# Show a list of all defined filters

use strict;
use warnings;
require './fail2ban-lib.pl';
our (%in, %text);

&ui_print_header(undef, $text{'filters_title'}, "");

my @filters = &list_filters();
print &ui_form_start("delete_filters.cgi", "post");
my @links = ( &select_all_link("d"),
	      &select_invert_link("d"),
	      &ui_link("edit_filter.cgi?new=1", $text{'filters_add'}) );
my @tds = ( "width=5" );
print &ui_links_row(\@links);
print &ui_columns_start([ "",
			  $text{'filters_name'},
			  $text{'filters_re'} ]);
foreach my $f (@filters) {
	my ($def) = grep { $_->{'name'} eq 'Definition' } @$f;
	next if (!$def);	# Skip default config file
	my $fail = &find_value("failregex", $def);
	$fail ||= "";
	my $fname = &filename_to_name($def->{'file'});
	if (length($fail) > 80) {
		$fail = substr($fail, 0, 80)." ...";
		}
	print &ui_checked_columns_row([
		&ui_link("edit_filter.cgi?file=".&urlize($def->{'file'}),
			 $fname),
		&html_escape($fail),
		], \@tds, "d", $def->{'file'});
	}
print &ui_columns_end();
print &ui_links_row(\@links);
print &ui_form_end([ [ undef, $text{'filters_delete'} ] ]);

&ui_print_footer("", $text{'index_return'});
