#!/usr/local/bin/perl
# save_defroute.cgi
# Save the default route

require './qmail-lib.pl';
&ReadParse();
&error_setup($text{'rsave_err'});
@routes = &list_routes();
$old = $routes[$in{'idx'}] if ($in{'idx'} ne '');

if ($old && $in{'direct'}) {
	&delete_route($old);
	}
else {
	&to_ipaddress($in{'defroute'}) || &to_ip6address($in{'defroute'}) ||
		&error(&text('rsave_eto', $in{'defroute'}));
	if ($old) {
		&modify_route($old, { 'from' => '',
				      'to' => $in{'defroute'} } );
		}
	else {
		&create_route({ 'from' => '',
			        'to' => $in{'defroute'} } );
		}
	}
&webmin_log("defroute", undef, undef, \%in);
&redirect("list_routes.cgi");

