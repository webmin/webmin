#!/usr/local/bin/perl
# search_user.cgi
# Search the list of users across all servers, and display the results

require './cluster-useradmin-lib.pl';
&ReadParse();

$m = $in{'match'};
$w = $in{'what'};
@hosts = &list_useradmin_hosts();
@servers = &list_servers();
foreach $h (@hosts) {
	($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
	foreach $u (@{$h->{'users'}}) {
		$f = $u->{$in{'field'}};
		if ($m == 0 && $f eq $w ||
		    $m == 1 && eval { $f =~ /$w/i } ||
		    $m == 4 && index($f, $w) >= 0 ||
		    $m == 2 && $f ne $w ||
		    $m == 3 && eval { $f !~ /$w/i } ||
		    $m == 5 && index($f, $w) < 0) {
			push(@{$hosts{$u->{'user'}}},
			     $s->{'desc'} ? $s->{'desc'} : $s->{'host'});
			push(@match, $u) if (!$found{$u->{'user'}}++);
			}
		}
	}
if (@match == 1) {
	&redirect("edit_user.cgi?user=".$match[0]->{'user'});
	}
else {
	&ui_print_header(undef, $text{'search_title'}, "");
	if (@match == 0) {
		print "<p><b>$text{'search_notfound'}</b>. <p>\n";
		}
	else {
		print "<table border width=100%>\n";
		print "<tr $tb> <td><b>$text{'user'}</b></td>\n";
		print "<td><b>$text{'uid'}</b></td>\n";
		print "<td><b>$text{'real'}</b></td>\n";
		print "<td><b>$text{'home'}</b></td>\n";
		print "<td><b>$text{'search_hosts'}</b></td> </tr>\n";
		foreach $m (@match) {
			$m->{'real'} =~ s/,.*$// if ($uconfig{'extra_real'});
			print "<tr $cb>\n";
			print "<td><a href=\"edit_user.cgi?user=$m->{'user'}\">$m->{'user'}</a></td>\n";
			print "<td>$m->{'uid'}</td>\n";
			print "<td>$m->{'real'}&nbsp;</td>\n";
			print "<td>$m->{'home'}</td>\n";
			@h = @{$hosts{$m->{'user'}}};
			@h = @h[0 .. 10], ".." if (@h > 10);
			print "<td>",join(", ", @h),"</td>\n";
			print "</tr>\n";
			}
		print "</table><p>\n";
		}
	&ui_print_footer("", $text{'index_return'});
	}

