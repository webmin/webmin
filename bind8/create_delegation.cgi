#!/usr/local/bin/perl
# create_forward.cgi
# Create a new forward zone
use strict;
use warnings;
# Globals
our (%access, %text, %in, %config);

require './bind8-lib.pl';
&ReadParse();
&error_setup($text{'dcreate_err'});
$access{'delegation'} || &error($text{'dcreate_ecannot'});
$access{'ro'} && &error($text{'master_ero'});
my $conf = &get_config();
my $vconf;
if ($in{'view'} ne '') {
	my $view = $conf->[$in{'view'}];
	&can_edit_view($view) || &error($text{'master_eviewcannot'});
	$vconf = $view->{'members'};
	}
else {
	$vconf = $conf;
	}

# validate inputs
if ($in{'rev'}) {
	my $ipv4;
	($ipv4 = &check_net_ip($in{'zone'})) ||
	$config{'support_aaaa'} &&
	(($in{'zone'} =~ /^([\w:]+)(\/\d+)$/) || &check_ip6address($1)) ||
		&error(&text('create_enet', $in{'zone'}));
	if ($ipv4) {
		$in{'zone'} = &ip_to_arpa($in{'zone'});
		}
	else {
		$in{'zone'} = &net_to_ip6int($1, ($2 ? substr($2, 1) : "" ));
		}
	}
else {
	($in{'zone'} =~ /^[\d\.]+$/ || $in{'zone'} =~ /^[\d\:]+(\/[\d]+)?$/) &&
		&error(&text('create_edom2', $in{'zone'}));
	&valdnsname($in{'zone'}, 0, ".") ||
		&error(&text('create_edom', $in{'zone'}));
	}
$in{'zone'} =~ s/\.$//;
foreach my $z (&find("zone", $vconf)) {
	if (lc($z->{'value'}) eq lc($in{'zone'})) {
		&error($text{'master_etaken'});
		}
	}

# Create structure
my $dir = { 'name' => 'zone',
	 'values' => [ $in{'zone'} ],
	 'type' => 1,
	 'members' => [ { 'name' => 'type',
			  'values' => [ 'delegation-only' ] }
		      ]
	};

# Create zone directive
&create_zone($dir, $conf, $in{'view'});
&webmin_log("create", "delegation", $in{'zone'}, \%in);

# Get the new zone's index
my $idx = &get_zone_index($in{'zone'}, $in{'view'});

&add_zone_access($in{'zone'});
&redirect("edit_delegation.cgi?zone=$in{'zone'}&view=$in{'view'}");

