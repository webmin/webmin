#!/usr/local/bin/perl
# edit_host.cgi
# Display users and groups on some host

require './cluster-useradmin-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'host_title'}, "");

@hosts = &list_useradmin_hosts();
($host) = grep { $_->{'id'} == $in{'id'} } @hosts;
$server = &foreign_call("servers", "get_server", $in{'id'});
@packages = @{$host->{'packages'}};

# Show host details
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'host_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'host_name'}</b></td>\n";
if ($server->{'id'}) {
	print "<td>";
	printf &ui_link("/servers/link.cgi/%s/","%s"),
		$server->{'id'},
		$server->{'desc'} ?
			"$server->{'desc'} ($server->{'host'}:$server->{'port'})" :
			"$server->{'host'}:$server->{'port'}";
	print "</td>";
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

print "<tr> <td><b>$text{'host_users'}</b></td>\n";
printf "<td>%d</td>\n", scalar(@{$host->{'users'}});

print "<td><b>$text{'host_groups'}</b></td>\n";
printf "<td>%d</td> </tr>\n", scalar(@{$host->{'groups'}});

print "</table></td></tr></table>\n";

# Show delete and refresh buttons
print "<table width=100%><tr>\n";
print "<form action=delete_host.cgi>\n";
print "<input type=hidden name=id value=$in{'id'}>\n";
print "<td><input type=submit value='$text{'host_delete'}'></td>\n";
print "</form>\n";

print "<form action=refresh.cgi>\n";
print "<input type=hidden name=id value=$in{'id'}>\n";
print "<td align=right><input type=submit value='$text{'host_refresh'}'></td>\n";
print "</form>\n";
print "</tr></table>\n";

# Show users and groups
print &ui_hr();
print &ui_subheading($text{'host_ulist'});
print "<table width=100% border>\n";
print "<tr $tb> <td><b>$text{'index_users'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";
foreach $u (@{$host->{'users'}}) {
	if ($i%4 == 0) { print "<tr>\n"; }
	print "<td><a href=\"edit_user.cgi?user=$u->{'user'}&",
	      "host=$server->{'id'}\">$u->{'user'}</a></td>\n";
	if ($i%4 == 3) { print "</tr>\n"; }
	$i++;
	}
print "</table></td> </tr></table>\n";

print &ui_subheading($text{'host_glist'});
print "<table width=100% border>\n";
print "<tr $tb> <td><b>$text{'index_groups'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";
foreach $g (@{$host->{'groups'}}) {
	if ($j%4 == 0) { print "<tr>\n"; }
	print "<td><a href=\"edit_group.cgi?group=$g->{'group'}&",
	      "host=$server->{'id'}\">$g->{'group'}</a></td>\n";
	if ($j%4 == 3) { print "</tr>\n"; }
	$j++;
	}
print "</table></td> </tr></table>\n";

&ui_print_footer("", $text{'index_return'});

