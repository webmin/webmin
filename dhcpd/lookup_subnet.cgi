#!/usr/local/bin/perl
# lookup_subnet.cgi
# Find a subnet with a certain address and re-direct to its editing form

require './dhcpd-lib.pl';
&ReadParse();
$in{'subnet'} || &error($text{'lookup_esubnetname'});

# Recursively find subnets
$conf = &get_config();
@subnets = &find_recursive("subnet", $conf);

# Look for a match
%access = &get_module_acl();
foreach $s (@subnets) {
	local $can_view = &can('r', \%access, $s);
	next if !$can_view && $access{'hide'};
	if (&search_re($s->{'values'}->[0], $in{'subnet'}) ||
	    &search_re($s->{'values'}->[0]."/".$s->{'values'}->[2], $in{'subnet'})) {
		$subnet = $s;
		last;
		}
	}

# Go to the subnet or show an error
if ($subnet) {
	($gidx, $uidx, $sidx) = &find_parents($subnet);
	&redirect("edit_subnet.cgi?idx=$subnet->{'index'}".
		  (defined($gidx) ? "&gidx=$gidx" : "").
		  (defined($uidx) ? "&uidx=$uidx" : "").
		  (defined($sidx) ? "&sidx=$sidx" : ""));
	}
else {
	&error(&text('lookup_esubnet', $in{'subnet'}));
	}

