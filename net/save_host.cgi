#!/usr/local/bin/perl
# save_host.cgi
# Create, update or delete a host address

require './net-lib.pl';
$access{'hosts'} == 2 || &error($text{'hosts_ecannot'});
&ReadParse();
&lock_file($config{'hosts_file'});
@hosts = &list_hosts();
if ($in{'delete'}) {
	# deleting a host
	$host = $hosts[$in{'idx'}];
	&delete_host($host);
	}
else {
	# saving or updating a host
	&check_ipaddress_any($in{'address'}) ||
		&error("'".&html_escape($in{'address'})."' is not a valid IP address");
	@h = split(/\s+/, $in{'hosts'});
	foreach $h (@h) {
		$h =~ /^[A-z0-9\-\.]+$/ ||
			&error("'".&html_escape($h)."' is not a valid hostname");
		}
	@h>0 || &error("You must enter at least one hostname");
	if ($in{'new'}) {
		# saving a host
		$host = { 'address' => $in{'address'},
			  'hosts' => \@h,
			  'active' => $in{'active'} };
		&create_host($host);
		}
	else {
		# updating a host
		$host = $hosts[$in{'idx'}];
		$host->{'address'} = $in{'address'};
		$host->{'hosts'} = \@h;
		$host->{'active'} = $in{'active'};
		&modify_host($host);
		}
	}
&unlock_file($config{'hosts_file'});
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    'host', $host->{'address'}, $host);
&redirect("list_hosts.cgi");

