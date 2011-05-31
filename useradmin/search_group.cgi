#!/usr/local/bin/perl
# search_group.cgi
# Search the group file, and display a list of results

require './user-lib.pl';
&ReadParse();
@glist = &list_groups();
$m = $in{'match'};
$w = lc($in{'what'});
for($i=0; $i<@glist; $i++) {
	$g = $glist[$i];
	$f = lc($g->{$in{'field'}});
	if ($m == 0 && $f eq $w ||
	    $m == 1 && eval { $f =~ /$w/i } ||
	    $m == 4 && index($f, $w) >= 0 ||
	    $m == 2 && $f ne $w ||
	    $m == 3 && eval { $f !~ /$w/i } ||
	    $m == 5 && index($f, $w) < 0 ||
	    $m == 6 && $f < $w ||
	    $m == 7 && $f > $w) {
		push(@match, $g);
		}
	}
if (@match == 1) {
	&redirect("edit_group.cgi?group=".$match[0]->{'group'});
	}
else {
	&ui_print_header(undef, $text{'search_title'}, "");
	if (@match == 0) {
		print "<b>$text{'search_gnotfound'}</b>. <p>\n";
		}
	else {
		print "<b>",&text('search_gfound', scalar(@match)),"</b><br>\n";
		@match = &sort_groups(\@match, $config{'sort_mode'});
		&groups_table(\@match);
		}
	&ui_print_footer("", $text{'index_return'});
	}

