#!/usr/local/bin/perl
# search_group.cgi
# Search the list of groups across all servers, and display the results

require './cluster-useradmin-lib.pl';
&ReadParse();
$m = $in{'match'};
$w = $in{'what'};
@hosts = &list_useradmin_hosts();
@servers = &list_servers();
foreach $h (@hosts) {
	($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
	foreach $g (@{$h->{'groups'}}) {
		$f = $g->{$in{'field'}};
		if ($m == 0 && $f eq $w ||
		    $m == 1 && eval { $f =~ /$w/i } ||
		    $m == 4 && index($f, $w) >= 0 ||
		    $m == 2 && $f ne $w ||
		    $m == 3 && eval { $f !~ /$w/i } ||
		    $m == 5 && index($f, $w) < 0) {
			push(@{$hosts{$g->{'group'}}},
			     $s->{'desc'} ? $s->{'desc'} : $s->{'host'});
			push(@match, $g) if (!$found{$g->{'group'}}++);
			}
		}
	}
if (@match == 1) {
	&redirect("edit_group.cgi?group=".$match[0]->{'group'});
	}
else {
	&ui_print_header(undef, $text{'search_title'}, "");
	if (@match == 0) {
		print "<p><b>$text{'search_gnotfound'}</b><p>\n";
		}
	else {
		print &ui_columns_start([ $text{'gedit_group'},
					  $text{'gedit_gid'},
					  $text{'gedit_members'},
					  $text{'search_hosts'} ], 100);
		foreach $m (@match) {
			local $members = join(" ", split(/,/, $m->{'members'}));
			@h = @{$hosts{$m->{'group'}}};
			@h = @h[0 .. 10], ".." if (@h > 10);
			print &ui_columns_row([
				&ui_link("edit_group.cgi?group=".
					 &urlize($m->{'group'}),
					 &html_escape($m->{'group'})),
				$m->{'gid'},
				&html_escape($members),
				join(", ", @h),
				]);
			}
		print &ui_columns_end();
		}
	&ui_print_footer("", $text{'index_return'});
	}

