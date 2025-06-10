#!/usr/local/bin/perl
# Show a table of all profiles

require './rbac-lib.pl';
$access{'profs'} || &error($text{'profs_ecannot'});
&ui_print_header(undef, $text{'profs_title'}, "", "profs");

$profs = &list_prof_attrs();
if (@$profs) {
	print &ui_link("edit_prof.cgi?new=1",$text{'profs_add'}),"<br>\n"
		if ($access{'profs'} == 1);
	print &ui_columns_start(
		[ $text{'profs_name'},
		  $text{'profs_desc'},
		  $text{'profs_auths'} ]);
	foreach $p (sort { $a->{'name'} cmp $b->{'name'} } @$profs) {
		print &ui_columns_row(
			[ $access{'profs'} == 1 ?
			    &ui_link("edit_prof.cgi?idx=$p->{'index'}",
				     $p->{'name'}) :
			    $p->{'name'},
			  &rbac_help_link($p, $p->{'desc'}),
			  &nice_comma_list($p->{'attr'}->{'auths'}),
			]);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'profs_none'}</b><p>\n";
	}
print &ui_link("edit_prof.cgi?new=1",$text{'profs_add'}),"<br>\n"
	if ($access{'profs'} == 1);

&ui_print_footer("", $text{"index_return"});
