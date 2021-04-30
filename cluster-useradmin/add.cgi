#!/usr/local/bin/perl
# add.cgi
# Add or update a server or group from the webmin servers module

require './cluster-useradmin-lib.pl';
&ReadParse();
@servers = &list_servers();

if ($in{'add'}) {
	# Add a single host
	@add = grep { $_->{'id'} eq $in{'server'} } @servers;
	&error_setup($text{'add_err'});
	$msg = &text('add_msg', &server_name($add[0]));
	}
else {
	# Add all from a group
	($group) = grep { $_->{'name'} eq $in{'group'} }
			&servers::list_all_groups(\@servers);
	foreach $m (@{$group->{'members'}}) {
		push(@add, grep { $_->{'host'} eq $m } @servers);
		}
	&error_setup($text{'add_gerr'});
	$msg = &text('add_gmsg', $in{'group'});
	}

&ui_print_header(undef, $text{'add_title'}, "");

print "<b>$msg</b><p>\n";

# Setup error handler for down hosts
sub add_error
{
$add_error_msg = join("", @_);
}
&remote_error_setup(\&add_error);

# Get the users and groups for each host
&foreign_require("useradmin", "user-lib.pl");
$pft = &foreign_call("useradmin", "passfiles_type");
$gft = &foreign_call("useradmin", "groupfiles_type");
foreach $s (@add) {
	$add_error_msg = undef;
	local $host = { 'id' => $s->{'id'} };
	local $useradmin = &remote_foreign_check($s->{'host'}, "useradmin");
	if ($add_error_msg) {
		print "$add_error_msg<p>\n";
		next;
		}
	if (!$useradmin) {
		print &text('add_echeck', $s->{'host'}),"<p>\n";
		next;
		}
	&remote_foreign_require($s->{'host'}, "useradmin", "user-lib.pl");

	local $rpft = &remote_foreign_call($s->{'host'}, "useradmin",
					   "passfiles_type");
	if ($pft != $rpft) {
		print &text('add_epft', $s->{'host'}),"<p>\n";
		next;
		}

	local @rusers = &remote_foreign_call($s->{'host'}, "useradmin",
					     "list_users");
	local @rgroups = &remote_foreign_call($s->{'host'}, "useradmin",
					      "list_groups");
	$host->{'users'} = \@rusers;
	$host->{'groups'} = \@rgroups;
	&save_useradmin_host($host);
	print &text('add_ok', &server_name($s), scalar(@rusers),
		    scalar(@rgroups)),"<p>\n";
	}
&remote_finished();
if ($in{'add'}) {
	&webmin_log("add", "host", $add[0]->{'host'});
	}
else {
	&webmin_log("add", "group", $in{'group'});
	}

&ui_print_footer("", $text{'index_return'});

