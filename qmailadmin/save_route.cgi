#!/usr/local/bin/perl
# save_route.cgi
# Save or delete an SMTP route

require './qmail-lib.pl';
&ReadParse();
&error_setup($text{'rsave_err'});

@routes = &list_routes();
$r = $routes[$in{'idx'}] if (defined($in{'idx'}));

if ($in{'delete'}) {
	# delete some route
	$logr = $r;
	&delete_route($r);
	}
else {
	# saving or creating .. check inputs
	$in{'from'} =~ /^[A-Za-z0-9\.\-]+$/ ||
		&error(&text('rsave_efrom', $in{'from'}));
	$in{'to_def'} ||
	    &to_ipaddress($in{'to'}) || &to_ip6address($in{'to'}) ||
			&error(&text('rsave_eto', $in{'to'}));
	$in{'port_def'} || $in{'port'} =~ /^\d+$/ ||
		&error(&text('rsave_eport', $in{'port'}));
	$newr{'from'} = $in{'from'};
	$newr{'to'} = $in{'to'};
	$newr{'port'} = $in{'port'} if (!$in{'port_def'});

	if ($in{'new'}) { &create_route(\%newr); }
	else { &modify_route($r, \%newr); }
	$logr = \%newr;
	}
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    "route", $logr->{'from'}, $logr);
&redirect("list_routes.cgi");

