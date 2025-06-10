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
print &ui_table_start($text{'host_header'}, undef, 4);

my $hmsg;
if ($server->{'id'}) {
	$hmsg = &ui_link("/servers/link.cgi/$server->{'id'}/",
		$server->{'desc'} ?
		    "$server->{'desc'} ($server->{'host'}:$server->{'port'})" :
		    "$server->{'host'}:$server->{'port'}");
	}
else {
	$hmsg = &ui_link("/", $text{'this_server'});
	}
print &ui_table_row($text{'host_name'}, $hmsg, 3);

if ($server->{'id'}) {
	my ($t) = grep { $_->[0] eq $server->{'type'} } @servers::server_types;
	print &ui_table_row($text{'host_type'}, $t ? $t->[1] : "");
	}

print &ui_table_row($text{'host_userscount'},
	scalar(@{$host->{'users'}}));

print &ui_table_row($text{'host_groupscount'},
	scalar(@{$host->{'groups'}}));

print &ui_table_end();

# Show delete and refresh buttons
print &ui_buttons_start();

print &ui_buttons_row("delete_host.cgi", $text{'host_delete'}, undef,
		      [ [ "id", $in{'id'} ] ]);

print &ui_buttons_row("refresh.cgi", $text{'host_refresh'}, undef,
		      [ [ "id", $in{'id'} ] ]);

print &ui_buttons_end();

# Show users and groups
print &ui_hr();
my @ugrid;
foreach my $u (@{$host->{'users'}}) {
	push(@ugrid, &ui_link("edit_user.cgi?user=".&urlize($u->{'user'}).
			      "&host=".&urlize($server->{'id'}), $u->{'user'}));
	}
print &ui_grid_table(\@ugrid, 4, 100, undef, undef, $text{'host_users'});

my @ggrid;
foreach $g (@{$host->{'groups'}}) {
	push(@ggrid, &ui_link("edit_group.cgi?group=".&urlize($g->{'group'}).
			     "&host=".&urlize($server->{'id'}), $g->{'group'}));
	}
print &ui_grid_table(\@ggrid, 4, 100, undef, undef, $text{'host_groups'});

&ui_print_footer("", $text{'index_return'});

