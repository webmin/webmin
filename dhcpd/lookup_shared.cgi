#!/usr/local/bin/perl
# lookup_shared.cgi
# Find a shared network with a certain name and re-direct to its editing form

require './dhcpd-lib.pl';
&ReadParse();
$in{'shared'} || &error($text{'lookup_esharedname'});

# Recursively find shared nets
$conf = &get_config();
@shareds = &find_recursive("shared-network", $conf);

# Look for a match
%access = &get_module_acl();
foreach $s (@shareds) {
	local $can_view = &can('r', \%access, $s);
	next if !$can_view && $access{'hide'};
	if (&search_re($s->{'values'}->[0], $in{'shared'})) {
		$shared = $s;
		last;
		}
	}

# Go to the shared network or show an error
if ($shared) {
	($gidx, $uidx, $sidx) = &find_parents($shared);
	&redirect("edit_shared.cgi?idx=$shared->{'index'}".
		  (defined($gidx) ? "&gidx=$gidx" : "").
		  (defined($uidx) ? "&uidx=$uidx" : "").
		  (defined($sidx) ? "&sidx=$sidx" : ""));
	}
else {
	&error(&text('lookup_eshared', $in{'shared'}));
	}

