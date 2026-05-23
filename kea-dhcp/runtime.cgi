#!/usr/local/bin/perl
# Display Kea runtime lease, pool, statistics, and log information.

use strict;
use warnings;
require './kea-dhcp-lib.pl';    ## no critic
&ReadParse();
our (%in, %text);
&error_setup($text{'eacl_aviol'});
&kea_assert_acl('runtime');

&ui_print_header(undef, $text{'runtime_title'}, "", undef, 1, 1);

# Keep runtime views grouped in one page so the module index stays focused on
# configuration, while admins still get the operational data old dhcpd exposed.
my @tabs = (
	[ 'active', $text{'tab_leases_active'} ],
	[ 'pools', $text{'tab_leases_pools'} ],
	[ 'stats', $text{'tab_leases_stats'} ],
	[ 'logs', $text{'tab_leases_logs'} ],
	);
my %valid = map { $_->[0] => 1 } @tabs;
my $mode = $in{'mode'} && $valid{$in{'mode'}} ? $in{'mode'} : 'active';
print &ui_tabs_start(\@tabs, "mode", $mode, 1);

print &ui_tabs_start_tab("mode", "active");
my ($dhcp4_lease_file) = &kea_lease_file(4);
my ($dhcp6_lease_file) = &kea_lease_file(6);
print &ui_div(&text('leases_desc',
		    &sane_file_cell($dhcp4_lease_file),
		    &sane_file_cell($dhcp6_lease_file)));
&print_active_leases(4);
&print_active_leases(6);
print &ui_tabs_end_tab("mode", "active");

print &ui_tabs_start_tab("mode", "pools");
print &ui_div($text{'leases_pools_desc'});
&print_pool_usage(4);
&print_pool_usage(6);
print &ui_tabs_end_tab("mode", "pools");

print &ui_tabs_start_tab("mode", "stats");
print &ui_div($text{'leases_stats_desc'});
&print_lease_statistics();
print &ui_tabs_end_tab("mode", "stats");

print &ui_tabs_start_tab("mode", "logs");
print &ui_div($text{'leases_logs_desc'});
&print_recent_logs();
print &ui_tabs_end_tab("mode", "logs");

print &ui_tabs_end(1);
&ui_print_footer("index.cgi", $text{'index_return'});

# print_active_leases(version)
# Renders active leases for one DHCP protocol version.
sub print_active_leases
{
my ($ver) = @_;
my ($leases, $err) = &kea_active_leases($ver);
print &ui_subheading(&text('comp_dhcp'.$ver));
&print_lease_error_notice($err);
return if ($err);
if (!@$leases) {
	print &ui_p(&text('leases_none', $ver));
	return;
	}

# Lease CSV files use different columns across DHCPv4/DHCPv6 and Kea versions;
# these helpers normalize the common fields administrators need most.
print &ui_columns_start([
	$text{'col_address'},
	$text{'col_id'},
	$text{'col_identifier'},
	$text{'col_hostname'},
	$text{'col_expires'},
	$text{'col_state'},
	], 100);
foreach my $lease (@$leases) {
	print &ui_columns_row([
		&html_escape(&kea_lease_address($lease)),
		&html_escape($lease->{'subnet_id'} || ""),
		&html_escape(&kea_lease_identifier($lease)),
		&html_escape($lease->{'hostname'} || ""),
		&html_escape(&kea_lease_expires($lease)),
		&html_escape(&kea_lease_state($lease)),
		]);
	}
print &ui_columns_end();
}

# print_pool_usage(version)
# Renders configured subnet pool counts beside active lease counts.
sub print_pool_usage
{
my ($ver) = @_;
my ($rows, $err) = &kea_pool_usage_rows($ver);
print &ui_subheading(&text('comp_dhcp'.$ver));
if ($err) {
	print &ui_alert_box(&html_escape($err), "warning", undef, undef, "");
	return;
	}
if (!@$rows) {
	print &ui_p(&text('leases_no_subnets', $ver));
	return;
	}

# This is intentionally per-subnet rather than per-range: Kea pools can be
# ranges, prefixes, and delegated prefix pools, and active lease CSV files only
# reliably tie leases back to subnet IDs.
print &ui_columns_start([
	$text{'col_id'},
	$text{'col_subnet'},
	$text{'col_pools'},
	$text{'col_pd_pools'},
	$text{'col_reservations'},
	$text{'col_active_leases'},
	], 100);
foreach my $row (@$rows) {
	print &ui_columns_row([
		&html_escape($row->{'id'}),
		&html_escape($row->{'subnet'}),
		$row->{'pools'},
		$row->{'pd_pools'},
		$row->{'reservations'},
		$row->{'active'},
		]);
	}
print &ui_columns_end();
}

# print_lease_statistics()
# Renders lease-file counters for DHCPv4 and DHCPv6.
sub print_lease_statistics
{
print &ui_columns_start([
	$text{'col_service'},
	$text{'col_active_leases'},
	$text{'col_total'},
	$text{'col_inactive'},
	$text{'col_file'},
	$text{'col_summary'},
	], 100);
foreach my $ver (4, 6) {
	my $s = &kea_lease_summary($ver);
	print &ui_columns_row([
		&html_escape(&text('comp_dhcp'.$ver)),
		$s->{'active'},
		$s->{'total'},
		$s->{'inactive'},
		&sane_file_cell($s->{'file'}),
		&html_escape($s->{'error'} || ""),
		]);
	}
print &ui_columns_end();
}

# print_recent_logs()
# Renders recent journal entries for configured Kea services.
sub print_recent_logs
{
print &ui_columns_start([
	$text{'col_service'},
	$text{'col_logs'},
	], 100, 0, [ "width=20%", "width=80%" ]);
foreach my $c (&kea_components()) {
	my $logs = &kea_recent_component_log_lines($c, 20);
	my $body = @$logs ? join(&ui_br(), map { &html_escape($_) } @$logs) :
		   &html_escape($text{'leases_no_logs'});
	print &ui_columns_row([
		&html_escape($c->{'label'}),
		$body,
		]);
	}
print &ui_columns_end();
}

# print_lease_error_notice(error)
# Shows non-fatal lease-file read errors for one active-lease table.
sub print_lease_error_notice
{
my ($err) = @_;
print &ui_alert_box(&html_escape($err), "warning", undef, undef, "") if ($err);
}

# sane_file_cell(file)
# Formats a configured file path for display without assuming it exists.
sub sane_file_cell
{
my ($file) = @_;
return "" if (!$file);
return &ui_tag('tt', &html_escape($file));
}
