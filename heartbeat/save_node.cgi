#!/usr/local/bin/perl
# save_node.cgi
# Save a node in the resources file

require './heartbeat-lib.pl';
&ReadParse();
&error_setup($text{'node_err'});
if (!$in{'new'}) {
	@res = &list_resources();
	$res = $res[$in{'idx'}];
	}

if ($in{'delete'}) {
	# Just delete this resource
	&delete_resource($res);
	&redirect("edit_res.cgi");
	exit;
	}

# Validate and store inputs
$in{'node'} =~ /^(\S+)$/ || &error($text{'node_enode'});
for($i=0; defined($in{"ip_$i"}); $i++) {
	next if (!$in{"ip_$i"});
	&check_ipaddress($in{"ip_$i"}) ||
		&error(&text('node_eip', $in{"ip_$i"}));
	local @ip = ( $in{"ip_$i"} );
	if (!$in{"cidr_def_$i"}) {
		$in{"cidr_$i"} =~ /^(\d+)$/ ||
			&error(&text('node_ecidr', $in{"cidr_$i"}));
		push(@ip, $in{"cidr_$i"});
		if (!$in{"broad_def_$i"}) {
			&check_ipaddress($in{"broad_$i"}) ||
				&error(&text('node_ebroad', $in{"broad_$i"}));
			push(@ip, $in{"broad_$i"});
			}
		}
	push(@ips, join("/", @ip));
	}
for($i=0; defined($in{"serv_$i"}); $i++) {
	next if (!$in{"serv_$i"});
	push(@servs, join("::", $in{"serv_$i"}, split(/\s+/, $in{"args_$i"})));
	}

# Create or update the resource
$res->{'node'} = $in{'node'};
$res->{'ips'} = \@ips;
$res->{'servs'} = \@servs;
if ($in{'new'}) {
	&create_resource($res);
	}
else {
	&modify_resource($res);
	}
&redirect("edit_res.cgi");

