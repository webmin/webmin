#!/usr/local/bin/perl
# edit_route.cgi
# Edit an existing SMTP route

require './qmail-lib.pl';
&ReadParse();
@routes = &list_routes();
$r = $routes[$in{'idx'}];

&ui_print_header(undef, $text{'rform_edit'}, "");
&route_form($r);
&ui_print_footer("list_routes.cgi", $text{'routes_return'});

