#!/usr/local/bin/perl
# save.cgi
# Create a new tunnel device

require './cipe-vpn-lib.pl';
&ReadParse();
&error_setup($text{'save_err'});
$dev = &get_config($in{'dev'}) if (!$in{'new'});

if ($in{'delete'}) {
	# Just delete this tunnel
	# XXX check if in use?
	&delete_config($dev);
	}
else {
	# Validate and store inputs
	$dev->{'desc'} = $in{'desc'};
	&check_ipaddress($in{'ipaddr'}) || &error($text{'save_eipaddr'});
	$dev->{'ipaddr'} = $in{'ipaddr'};
	&check_ipaddress($in{'ptpaddr'}) || &error($text{'save_eptpaddr'});
	$dev->{'ptpaddr'} = $in{'ptpaddr'};
	&parse_address("me", 1);
	&parse_address("peer", 0);
	$in{'key'} =~ /^[a-z0-9]{32,}$/i || &error($text{'save_ekey'});
	$dev->{'key'} = $in{'key'};
	$in{'def_def'} || &check_ipaddress($in{'def'}) ||
		&error($text{'save_edef'});
	$dev->{'def'} = $in{'def_def'} ? undef : $in{'def'};
	for($i=0; defined($t = $in{"type_$i"}); $i++) {
		next if (!$t);
		if ($t == 1) {
			&check_ipaddress($in{"net_$i"}) ||
				&error(&text('save_enet', $i+1));
			&check_ipaddress($in{"mask_$i"}) ||
				&error(&text('save_emask', $i+1));
			$in{"gw_def_$i"} || &check_ipaddress($in{"gw_$i"}) ||
				&error(&text('save_egw', $i+1));
			push(@route, [ 1, $in{"net_$i"}, $in{"mask_$i"},
			       $in{"gw_def_$i"} ? 'GW' : $in{"gw_$i"} ]);
			}
		else {
			&check_ipaddress($in{"net_$i"}) ||
				&error(&text('save_ehost', $i+1));
			$in{"mask_$i"} && &error(&text('save_emask2', $i+1));
			$in{"gw_def_$i"} || &check_ipaddress($in{"gw_$i"}) ||
				&error(&text('save_egw2', $i+1));
			push(@route, [ 2, $in{"net_$i"}, "255.255.255.255",
			       $in{"gw_def_$i"} ? 'GW' : $in{"gw_$i"} ]);
			}
		}
	$dev->{'route'} = \@route;

	# Create or update
	$dev->{'device'} = $in{'dev'};
	if ($in{'new'}) {
		$dev->{'dynip'} = 'yes';
		$dev->{'maxerr'} = -1;
		}
	&save_config($dev);
	}
&redirect("");

# parse_address(name, optional)
sub parse_address
{
local @rv;
if ($in{"$_[0]_ip_def"}) {
	push(@rv, "0.0.0.0");
	}
else {
	local $a = $in{"$_[0]_ip"};
	&to_ipaddress($a) ||
		&error(&text('save_eaddr', $a));
	push(@rv, $a);
	}
if (!$in{"$_[0]_port_def"}) {
	local $p = $in{"$_[0]_port"};
	$p =~ /^\d+$/ || &error(&text('save_eport', $p));
	push(@rv, $p);
	}
$dev->{$_[0]} = join(":", @rv);
}

