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
		print "<p><b>$text{'search_notfound'}</b><p>\n";
		}
	else {
		print &ui_columns_start([ $text{'user'},
					  $text{'uid'},
					  $text{'real'},
					  $text{'home'},
					  $text{'search_hosts'} ], 100);
		foreach $m (@match) {
			$m->{'real'} =~ s/,.*$// if ($uconfig{'extra_real'});
			@h = @{$hosts{$m->{'user'}}};
			@h = @h[0 .. 10], ".." if (@h > 10);
			print &ui_columns_row([
				&ui_link("edit_user.cgi?user=".
					 &urlize($m->{'user'}),
					 &html_escape($m->{'user'})),
				$m->{'uid'},
				&html_escape($m->{'real'}),
				&html_escape($m->{'home'}),
				join(", ", @h),
				]);
			}
		print &ui_columns_end();
		}
	&ui_print_footer("", $text{'index_return'});
	}

