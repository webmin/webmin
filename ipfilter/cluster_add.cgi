#!/usr/local/bin/perl
# Add or update a server or group from the webmin servers module

require './ipfilter-lib.pl';
&ReadParse();
&foreign_require("servers", "servers-lib.pl");
@allservers = grep { $_->{'user'} } &servers::list_servers();

if ($in{'add'}) {
	# Add a single host
	@add = grep { $_->{'id'} eq $in{'server'} } @allservers;
	&error_setup($text{'add_err'});
	$msg = &text('add_msg', &server_name($add[0]));
	}
else {
	# Add all from a group
	($group) = grep { $_->{'name'} eq $in{'group'} }
			&servers::list_all_groups(\@allservers);
	foreach $m (@{$group->{'members'}}) {
		push(@add, grep { $_->{'host'} eq $m } @allservers);
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

# Make sure each host is set up for firewalling
foreach $s (@add) {
	$add_error_msg = undef;
	local $firewall = &remote_foreign_check($s, "ipfilter");
	if ($add_error_msg) {
		print "$add_error_msg<p>\n";
		next;
		}
	if (!$firewall) {
		print &text('add_echeck', $s->{'host'}),"<p>\n";
		next;
		}
	&remote_foreign_require($s, "ipfilter", "ipfilter-lib.pl");

	local $missing = &remote_foreign_call($s, "ipfilter",
					      "missing_firewall_commands");
	if ($missing) {
		print &text('add_emissing', "<tt>$missing</tt>"),"<p>\n";
		next;
		}

	$live = &remote_foreign_call($s, "ipfilter", "get_live_config");
	print &text('add_ok', $s->{'host'}, scalar(@$live)),"<p>\n";
	&add_cluster_server($s);
	}
&remote_finished();
if ($in{'add'}) {
	&webmin_log("add", "host", $add[0]->{'host'});
	}
else {
	&webmin_log("add", "group", $in{'group'});
	}

&ui_print_footer("cluster.cgi", $text{'cluster_return'});

