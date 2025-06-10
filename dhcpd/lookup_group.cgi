#!/usr/local/bin/perl
# lookup_group.cgi
# Find a group with a certain name and re-direct to its editing form

require './dhcpd-lib.pl';
&ReadParse();
$in{'group'} || &error($text{'lookup_egroupname'});

# Recursively find groups
$conf = &get_config();
@groups = &find_recursive("group", $conf);

# Look for a match
%access = &get_module_acl();
foreach $g (@groups) {
	local $can_view = &can('r', \%access, $g);
	next if !$can_view && $access{'hide'};
	local @opts = &find("option", $g->{'members'});
	local ($dn) = grep { $_->{'values'}->[0] eq 'domain-name' } @opts;
	if (&search_re($g->{'values'}->[0], $in{'group'}) ||
	    $dn && &search_re($dn->{'values'}->[1], $in{'group'})) {
		$group = $g;
		last;
		}
	}

# Go to the group or show an error
if ($group) {
	($gidx, $uidx, $sidx) = &find_parents($group);
	&redirect("edit_group.cgi?idx=$group->{'index'}".
		  (defined($gidx) ? "&gidx=$gidx" : "").
		  (defined($uidx) ? "&uidx=$uidx" : "").
		  (defined($sidx) ? "&sidx=$sidx" : ""));
	}
else {
	&error(&text('lookup_egroup', $in{'group'}));
	}

