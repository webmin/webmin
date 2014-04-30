#!/usr/local/bin/perl
# Show a list of all defined filters

use strict;
use warnings;
require './fail2ban-lib.pl';
our (%in, %text);

&ui_print_header(undef, $text{'filters_title'}, "");

my @filters = &list_filters();
print &ui_columns_start([ $text{'filters_name'},
			  $text{'filters_re'} ]);
foreach my $f (@filters) {
	my ($def) = grep { $_->{'name'} eq 'Definition' } @$f;
	next if (!$f);	# XXX what about default?
	my $fail = &find_value("failregex", $f);
	my $fname = "XXX";
	print &ui_columns_row([
		&ui_link("edit_filter.cgi?file=".&urlize($def->{'file'}),
			 $fname),
		&html_escape($fail),
		]);
	}
print &ui_columns_end();

&ui_print_footer("", $text{'index_return'});
