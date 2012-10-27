#!/usr/local/bin/perl
# create_forward.cgi
# Create a new forward zone

require './bind8-lib.pl';
&ReadParse();
&error_setup($text{'dcreate_err'});
$access{'delegation'} || &error($text{'dcreate_ecannot'});
$access{'ro'} && &error($text{'master_ero'});
$conf = &get_config();
if ($in{'view'} ne '') {
	$view = $conf->[$in{'view'}];
	&can_edit_view($view) || &error($text{'master_eviewcannot'});
	$vconf = $view->{'members'};
	}
else {
	$vconf = $conf;
	}

# validate inputs
if ($in{'rev'}) {
	local($ipv4);
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
foreach $z (&find("zone", $vconf)) {
	if (lc($z->{'value'}) eq lc($in{'zone'})) {
		&error($text{'master_etaken'});
		}
	}

# Create structure
@mdirs = map { { 'name' => $_ } } @masters;
$dir = { 'name' => 'zone',
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
$idx = &get_zone_index($in{'zone'}, $in{'view'});

&add_zone_access($in{'zone'});
&redirect("edit_delegation.cgi?zone=$in{'zone'}&view=$in{'view'}");

