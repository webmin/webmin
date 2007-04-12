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
		print "<p><b>$text{'search_gnotfound'}</b>. <p>\n";
		}
	else {
		print "<table border width=100%>\n";
		print "<tr $tb> <td><b>$text{'gedit_group'}</b></td>\n";
		print "<td><b>$text{'gedit_gid'}</b></td>\n";
		print "<td><b>$text{'gedit_members'}</b></td>\n";
		print "<td><b>$text{'search_hosts'}</b></td> </tr>\n";
		foreach $m (@match) {
			local $members = join(" ", split(/,/, $m->{'members'}));
			print "<tr $cb>\n";
			print "<td><a href=\"edit_group.cgi?group=$m->{'group'}\">$m->{'group'}</a></td>\n";
			print "<td>$m->{'gid'}</td>\n";
			print "<td>$members&nbsp;</td>\n";
			@h = @{$hosts{$m->{'group'}}};
			@h = @h[0 .. 10], ".." if (@h > 10);
			print "<td>",join(", ", @h),"</td>\n";
			print "</tr>\n";
			}
		print "</table><p>\n";
		}
	&ui_print_footer("", $text{'index_return'});
	}

