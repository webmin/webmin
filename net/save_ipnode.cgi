#!/usr/local/bin/perl
# save_ipnode.cgi
# Create, update or delete a ipnode address

require './net-lib.pl';
$access{'ipnodes'} == 2 || &error($text{'ipnodes_ecannot'});
&ReadParse();
&lock_file($config{'ipnodes_file'});
@ipnodes = &list_ipnodes();
if ($in{'delete'}) {
	# deleting a ipnode
	$ipnode = $ipnodes[$in{'idx'}];
	&delete_ipnode($ipnode);
	}
else {
	# saving or updating a ipnode
	$whatfailed = "Failed to save ipnode";
	&check_ipaddress($in{'address'}) ||
	   &check_ip6address($in{'address'}) ||
		&error("'".&html_escape($in{'address'})."' is not a valid IPv4 or v6 address");
	@h = split(/\s+/, $in{'ipnodes'});
	foreach $h (@h) {
		$h =~ /^[A-z0-9\-\.]+$/ ||
			&error("'".&html_escape($h)."' is not a valid ipnodename");
		}
	@h>0 || &error("You must enter at least one ipnodename");
	if ($in{'new'}) {
		# saving a ipnode
		$ipnode = { 'address' => $in{'address'},
			  'ipnodes' => \@h };
		&create_ipnode($ipnode);
		}
	else {
		# updating a ipnode
		$ipnode = $ipnodes[$in{'idx'}];
		$ipnode->{'address'} = $in{'address'};
		$ipnode->{'ipnodes'} = \@h;
		&modify_ipnode($ipnode);
		}
	}
&unlock_file($config{'ipnodes_file'});
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    'ipnode', $ipnode->{'address'}, $ipnode);
&redirect("list_ipnodes.cgi");

