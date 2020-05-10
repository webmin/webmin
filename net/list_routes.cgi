#!/usr/local/bin/perl
# list_routes.cgi
# List boot-time routing configuration

require './net-lib.pl';
$access{'routes'} || &error($text{'routes_ecannot'});
&ReadParse();
&ui_print_header(undef, $text{'routes_title'}, "");

# Start of tabs for boot time / active routes
@tabs = ( [ "boot", $text{'routes_tabboot'}, "list_routes.cgi?mode=boot" ] );
if (defined(&list_routes)) {
	push(@tabs, [ "active", $text{'routes_tabactive'},
		      "list_routes.cgi?mode=active" ] );
	}
print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || $tabs[0]->[0], 1);

# Show boot-time routes
print &ui_tabs_start_tab("mode", "boot");
print $text{'routes_descboot'},"<p>\n";
print &ui_form_start("save_routes.cgi", "post");
print &ui_table_start($routes_active_now ? $text{'routes_now'}
					 : $text{'routes_boot'}, undef, 2);

# OS-specific routes function
&routing_input();

print &ui_table_end();
if ($access{'routes'} == 2) {
	print &ui_form_end([ [ undef, $routes_active_now ? $text{'bifc_apply'}
							 : $text{'save'} ] ] );
	}
else {
	print &ui_form_end();
	}
print &ui_tabs_end_tab("mode", "boot");

# Active routes tab
if (defined(&list_routes) || defined(&create_route)) {
	print &ui_tabs_start_tab("mode", "active");
	print $text{'routes_descactive'},"<p>\n";
	}

# Show routes active now
if (defined(&list_routes)) {
	if (defined(&delete_route)) {
		# With deletion button
		print &ui_form_start("delete_routes.cgi", "post");
		}
	local @tds = defined(&delete_route) ? ( "width=5" ) : ( );
	print &ui_columns_start([ defined(&delete_route) ? ( "" ) : ( ),
				  $text{'routes_dest'},
				  $text{'routes_gw'},
				  $text{'routes_mask'},
				  $text{'routes_iface'} ], undef, 0, \@tds, 0, 1);
	$i = 0;
	foreach $route (&list_routes()) {
		local @cols = (
			$route->{'dest'} eq "0.0.0.0" ? $text{'routes_def'} :
			$route->{'dest'} eq "::" ? $text{'routes_def6'} :
						   $route->{'dest'},
			$route->{'gateway'} eq "0.0.0.0" ? $text{'routes_nogw'}:
			$route->{'gateway'} eq "::" ? $text{'routes_nogw'}
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

if (defined(&list_routes) || defined(&create_route)) {
	print &ui_tabs_end_tab("mode", "active");
	}
print &ui_tabs_end(1);

&ui_print_footer("", $text{'index_return'});

