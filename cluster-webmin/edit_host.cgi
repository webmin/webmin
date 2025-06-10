#!/usr/local/bin/perl
# edit_host.cgi
# Show details of a managed host, and all the modules on it

require './cluster-webmin-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'host_title'}, "");

@hosts = &list_webmin_hosts();
($host) = grep { $_->{'id'} eq $in{'id'} } @hosts;
$server = &foreign_call("servers", "get_server", $in{'id'});
@modules = @{$host->{'modules'}};
@themes = @{$host->{'themes'}};
@users = @{$host->{'users'}};
@groups = @{$host->{'groups'}};

# Show host details
print "<input type=hidden name=id value=$in{'id'}>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'host_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'host_name'}</b></td>\n";
if ($server->{'id'}) {
	printf "<td><a href='../servers/link.cgi/%s/'>%s</a></td>\n",
		$server->{'id'}, $server->{'desc'} ? "$server->{'desc'} ($server->{'host'}:$server->{'port'})" : "$server->{'host'}:$server->{'port'}";
	}
else {
	print "<td><a href=/>$text{'this_server'}</a></td>\n";
	}

if ($server->{'id'}) {
	print "<td><b>$text{'host_type'}</b></td> <td>\n";
	foreach $t (@servers::server_types) {
		print $t->[1] if ($t->[0] eq $server->{'type'});
		}
	print "</td>\n";
	}
print "</tr>\n";

print "<tr> <td><b>$text{'host_count'}</b></td>\n";
printf "<td>%d</td>\n", scalar(@modules);

print "<td><b>$text{'host_tcount'}</b></td>\n";
printf "<td>%d</td> </tr>\n", scalar(@themes);

print "<tr> <td><b>$text{'host_os'}</b></td>\n";
print "<td>$host->{'real_os_type'} $host->{'real_os_version'}</td>\n";

print "<td><b>$text{'host_version'}</b></td>\n";
printf "<td>%s</td> </tr>\n", $host->{'version'};

print "</table></td></tr></table>\n";

# Show delete and refresh buttons
print "<p></p><table width=100%><tr>\n";

print "<td><form action=delete_host.cgi>\n";
print "<input type=hidden name=id value=$in{'id'}>\n";
print "<input type=submit value='$text{'host_delete'}'>\n";
print "</form></td>\n";

print "<td align=right><form action=refresh.cgi>\n";
print "<input type=hidden name=id value=$in{'id'}>\n";
print "<input type=submit value='$text{'host_refresh'}'>\n";
print "</form></td>\n";

print "</tr></table>\n";

# Show table of modules and themes
print "<p></p><table border width=100%>\n";
print "<tr $tb> <td><b>$text{'host_header_m'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

$i = 0;
my $total_cells = scalar(@modules);
foreach $m (sort { $a->{'desc'} cmp $b->{'desc'} } @modules) {
	my $colspan = '';
	if ($total_cells == $i + 1 && $total_cells%$i == 1) {
		if ($i%3 == 0) {
			$colspan = " colspan=3 ";
		} elsif($i%3 == 1) {
			$colspan = " colspan=2 ";
		}
	}
	print "<tr>\n" if ($i%3 == 0);
	print "<td $colspan width=33%><a href='edit_mod.cgi?mod=$m->{'dir'}&host=$in{'id'}'>",$m->{'desc'},"</td>\n";
	print "</tr>\n" if ($i%3 == 2);
	$i++;
	}
if (@themes) {
	$i = 0;
	print "</table></td></tr>\n";
	print "<tr $tb> <td><b>$text{'host_header_t'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";
	my $total_cells_themes = scalar(@themes);
	foreach $t (sort { $a->{'desc'} cmp $b->{'desc'} } @themes) {
		my $colspan = '';
		if ($total_cells_themes == $i + 1 && $total_cells_themes%$i == 1) {
			if ($i%3 == 0) {
				$colspan = " colspan=3 ";
			} elsif($i%3 == 1) {
				$colspan = " colspan=2 ";
			}
		}
		print "<tr>\n" if ($i%3 == 0);
		print "<td $colspan width=33%><a href='edit_mod.cgi?theme=$t->{'dir'}$in{'id'}'>",$t->{'desc'},"</td>\n";
		print "</tr>\n" if ($i%3 == 2);
		$i++;
		}
	}
print "</table></td></tr></table><br>\n";

# Show table of users and groups
print "<p></p><table border width=100%>\n";
print "<tr $tb> <td><b>$text{'host_header_u'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";
$i = 0;
foreach $u (@users) {
	print "<tr>\n" if ($i%4 == 0);
	print "<td width=25%><a href='edit_user.cgi?user=$u->{'name'}&host=$in{'id'}'>$u->{'name'}</td>\n";
	print "</tr>\n" if ($i%4 == 3);
	$i++;
	}
if ($i%4) {
	while($i++%4) { print "<td width=25%></td>\n"; }
	print "</tr>\n";
	}
if (@groups) {
	$i = 0;
	print "</table></td></tr>\n";
	print "<tr $tb> <td><b>$text{'host_header_g'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";
	foreach $g (@groups) {
		print "<tr>\n" if ($i%4 == 0);
		print "<td width=25%><a href='edit_group.cgi?group=$g->{'name'}&host=$in{'id'}'>$g->{'name'}</td>\n";
		print "</tr>\n" if ($i%4 == 3);
		$i++;
		}
	if ($i%4) {
		while($i++%4) { print "<td width=25%></td>\n"; }
		print "</tr>\n";
		}
	}
print "</table></td></tr></table><br>\n";

&ui_print_footer("", $text{'index_return'});

