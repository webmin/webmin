#!/usr/local/bin/perl
# Show a form for editing or creating a filter

use strict;
use warnings;
require './fail2ban-lib.pl';
our (%in, %text);
&ReadParse();

my ($filter, $def);

# Show header and get the filter object
if ($in{'new'}) {
	&ui_print_header(undef, $text{'filter_title1'}, "");
	$filter = [ ];
	$def = { 'members' => [ ] };
	}
else {
	&ui_print_header(undef, $text{'filter_title2'}, "");
	($filter) = grep { $_->[0]->{'file'} eq $in{'file'} } &list_filters();
	$filter || &error($text{'filter_egone'});
	($def) = grep { $_->{'name'} eq 'Definition' } @$filter;
	$def || &error($text{'filter_edefgone'});
	}

print &ui_form_start("save_filter.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("file", $in{'file'});
print &ui_table_start($text{'filter_header'}, undef, 2);

# Service name
if ($in{'new'}) {
	print &ui_table_row($text{'filter_name'},
		&ui_textbox("name", undef, 30));
	}
else {
	my $fname = &filename_to_name($def->{'file'});
	print &ui_table_row($text{'filter_name'},
		"<tt>".&html_escape($fname)."</tt>");
	}

# Regexp to match
my $fail = &find_value("failregex", $def);
print &ui_table_row($text{'filter_fail'},
	&ui_textarea("fail", $fail, 5, 80, "off")."<br>\n".
	$text{'filter_desc'});

# Regexp to not match
my $ignore = &find_value("ignoreregex", $def);
print &ui_table_row($text{'filter_ignore'},
	&ui_textarea("ignore", $ignore, 5, 80, "off"));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("list_filters.cgi", $text{'filters_return'});

