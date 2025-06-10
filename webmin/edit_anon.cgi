#!/usr/local/bin/perl
# edit_anon.cgi
# Display anonymous access form

require './webmin-lib.pl';
&ui_print_header(undef, $text{'anon_title'}, "");
&get_miniserv_config(\%miniserv);

# Build list of users
print $text{'anon_desc'},"<br>\n";
print "<b>",$text{'anon_desc2'},"</b><p>\n";
foreach $a (split(/\s+/, $miniserv{'anonymous'})) {
	if ($a =~ /^([^=]+)=(\S+)$/) {
		push(@anon, [ $1, $2 ]);
		}
	}

# Build table data
$i = 0;
foreach my $a (@anon, [ ], [ ]) {
	push(@table, [ &ui_textbox("url_$i", $a->[0], 40),
		       &ui_textbox("user_$i", $a->[1], 30) ]);
	$i++;
	}

# Show the table
print &ui_form_columns_table(
	"change_anon.cgi", 
	[ [ undef, $text{'save'} ] ],
	0,
	undef,
	undef,
	[ $text{'anon_url'}, $text{'anon_user'} ],
	undef,
	\@table,
	undef,
	1);

&ui_print_footer("", $text{'index_return'});

