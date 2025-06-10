#!/usr/local/bin/perl
# Add or update a server or group from the webmin servers module

require './lpadmin-lib.pl';
$access{'cluster'} || &error($text{'cluster_ecannot'});
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

# Make sure each host is set up for printer administration
foreach $s (@add) {
	$add_error_msg = undef;
	local $host = { 'id' => $s->{'id'} };
	local $lpadmin = &remote_foreign_check($s->{'host'}, "lpadmin");
	if ($add_error_msg) {
		print "$add_error_msg<p>\n";
		next;
		}
	if (!$lpadmin) {
		print &text('add_echeck', $s->{'host'}),"<p>\n";
		next;
		}
	&remote_foreign_require($s->{'host'}, "lpadmin", "lpadmin-lib.pl");
	local $lconfig = &remote_foreign_config($s, "lpadmin");
	if ($lconfig->{'print_style'} ne $config{'print_style'}) {
		print &text('add_ediff', $s->{'host'},
			    $text{'style_'.$lconfig->{'print_style'}}),"<p>\n";
		next;
		}
	if ($lconfig->{'driver_style'} ne $config{'driver_style'}) {
		print &text('add_ediff', $s->{'host'},
			    $lconfig->{'driver_style'} || "Webmin"),"<p>\n";
		next;
		}

	@printers = &remote_foreign_call($s->{'host'}, "lpadmin",
					 "list_printers");
	print &text('add_ok', $s->{'host'}, scalar(@printers)),"<p>\n";
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

