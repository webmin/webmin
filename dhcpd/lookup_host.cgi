#!/usr/local/bin/perl
# lookup_host.cgi
# Find a host with a certain name and re-direct to its editing form

require './dhcpd-lib.pl';
&ReadParse();
$in{'host'} || &error($text{'lookup_ehostname'});

# Recursively find hosts
$conf = &get_config();
@hosts = &find_recursive("host", $conf);

# Look for a match
%access = &get_module_acl();
foreach $h (@hosts) {
	local $can_view = &can('r', \%access, $h);
	next if !$can_view && $access{'hide'};
	local $fixed = &find("fixed-address", $h->{'members'});
	local $hard = &find("hardware", $h->{'members'});
	if (&search_re($h->{'values'}->[0], $in{'host'}) ||
	    $fixed && &search_re($fixed->{'values'}->[0], $in{'host'}) ||
	    $hard && &search_re($hard->{'values'}->[1], $in{'host'})) {
		$host = $h;
		last;
		}
	}

# Go to the host or show an error
if ($host) {
	($gidx, $uidx, $sidx) = &find_parents($host);
	&redirect("edit_host.cgi?idx=$host->{'index'}".
		  (defined($gidx) ? "&gidx=$gidx" : "").
		  (defined($uidx) ? "&uidx=$uidx" : "").
		  (defined($sidx) ? "&sidx=$sidx" : ""));
	}
else {
	&error(&text('lookup_ehost', $in{'host'}));
	}

