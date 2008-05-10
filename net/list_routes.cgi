#!/usr/local/bin/perl
# list_routes.cgi
# List boot-time routing configuration

require './net-lib.pl';
$access{'routes'} || &error($text{'routes_ecannot'});
&ReadParse();
&ui_print_header(undef, $text{'routes_title'}, "");

# Show boot-time routes
print "<form action=save_routes.cgi method=post>\n";
print "<table border>\n";
print "<tr $tb> <td><b>",
      $routes_active_now? $text{'routes_now'} : $text{'routes_boot'},
      "</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";
&routing_input();
print "</table></td></tr></table>\n";
printf "<input type=submit value=\"%s\">\n",
    ($routes_active_now?  $text{'bifc_apply'} : $text{'save'})
	if ($access{'routes'} == 2);
print "</form>\n";

# Show routes active now
print &ui_hr();
if (defined(&list_routes)) {
	if (defined(&delete_route)) {
		# With deletion button
		print &ui_form_start("delete_routes.cgi", "post");
		}
	print &ui_subheading($text{'routes_active'});
	local @tds = defined(&delete_route) ? ( "width=5" ) : ( );
	print &ui_columns_start([ defined(&delete_route) ? ( "" ) : ( ),
				  $text{'routes_dest'},
				  $text{'routes_gw'},
				  $text{'routes_mask'},
				  $text{'routes_iface'} ], undef, 0, \@tds);
	$i = 0;
	foreach $route (&list_routes()) {
		local @cols = (
			$route->{'dest'} eq "0.0.0.0" ? $text{'routes_def'}
						      : $route->{'dest'},
			$route->{'gateway'} eq "0.0.0.0" ? $text{'routes_nogw'}
							 : $route->{'gateway'},
			$route->{'netmask'} eq "0.0.0.0" ? ""
							 : $route->{'netmask'},
			$route->{'iface'} || $text{'routes_any'},
			);
		if (defined(&delete_route)) {
			print &ui_checked_columns_row(\@cols, \@tds, "d", $i++);
			}
		else {
			print &ui_columns_row(\@cols, \@tds);
			}
		}
	print &ui_columns_end();
	if (defined(&delete_route)) {
		print &ui_form_end([ [ "delete", $text{'routes_delete'} ] ]);
		}
	}

# Show form to add a route
if (defined(&create_route)) {
	print &ui_form_start("create_route.cgi", "post");
	print &ui_table_start($text{'routes_cheader'}, undef, 2);

	print &ui_table_row($text{'routes_cdest'},
			    &ui_opt_textbox("dest", undef, 30,
					    $text{'routes_cdef'}));

	print &ui_table_row($text{'routes_cnetmask'},
			    &ui_opt_textbox("netmask", "255.255.255.255", 30,
					    $text{'default'}));

	$ciface = &ui_select("iface", undef,
		     [ map { [ $_->{'fullname'} ] }
			   grep { $_->{'virtual'} eq '' } &boot_interfaces() ]);
	$cgateway = &ui_textbox("gateway", undef, 30);
	print &ui_table_row($text{'routes_cvia'},
	    &ui_radio("via", 0, [ [ 0, &text('routes_ciface', $ciface) ],
				  [ 1, &text('routes_cgw', $cgateway) ] ]));

	print &ui_table_end();
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

