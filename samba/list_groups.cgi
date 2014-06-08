#!/usr/local/bin/perl
# list_group.cgi
# List all existing Samba groups

require './samba-lib.pl';

$access{'maint_groups'} || &error($text{'groups_ecannot'});
&ui_print_header(undef, $text{'groups_title'}, "");

&check_group_enabled($text{'groups_cannot'});

@groups = &list_groups();
@links = ( &ui_link("edit_group.cgi?new=1",$text{'groups_add'}) );
if (@groups) {
	@groups = sort { lc($a->{'name'}) cmp lc($b->{'name'}) } @groups
		if ($config{'sort_mode'});
	print &ui_links_row(\@links);
	print &ui_columns_start([ $text{'groups_name'},
				  $text{'groups_unix'},
				  $text{'groups_type'},
				  $text{'groups_sid'} ]);
	foreach $g (@groups) {
		print &ui_columns_row([
			&ui_link("edit_group.cgi?idx=$g->{'index'}",&html_escape($g->{'name'})),
			$g->{'unix'} == -1 ? $text{'groups_nounix'} :
			  "<tt>".&html_escape($g->{'unix'})."</tt>",
			$text{'groups_type_'.$g->{'type'}} ||
			  &html_escape($g->{'type'}),
			"<tt>".&html_escape($g->{'sid'})."</tt>",
			]);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'groups_none'}</b><p>\n";
	}
print &ui_links_row(\@links);

&ui_print_footer("", $text{'index_sharelist'});

