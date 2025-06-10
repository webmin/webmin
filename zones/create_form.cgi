#!/usr/local/bin/perl
# Shows a form for adding a new zone

require './zones-lib.pl';
do 'forms-lib.pl';
use Socket;
&ReadParse();
$p = new WebminUI::Page(undef, $text{'create_title'}, "create");
$p->add_form(&get_create_form(\%in));
$p->add_footer("index.cgi", $text{'index_return'});
$p->print();
exit;

&ui_print_header(undef, $text{'create_title'}, "", "create");
&foreign_require("time", "time-lib.pl");

print &ui_form_start("create_zone.cgi", "post");
print &ui_table_start($text{'create_header'}, undef, 2);

print &ui_table_row($text{'edit_name'},
		    &ui_textbox("name", undef, 20));

print &ui_table_row($text{'create_path'},
		    &ui_opt_textbox("path", undef, 30,
			&text('create_auto', $config{'base_dir'}),
			$text{'create_sel'})."\n".
		    &file_chooser_button("path", 1));
		    
print &ui_table_row($text{'create_brand'},
			&ui_select("brand",undef, [ &list_brands() ], 0, 0, $value ? 1 : 0));

print &ui_table_row($text{'create_address'},
		    &ui_opt_textbox("address", undef, 20,
				    $text{'create_noaddress'}));

print &ui_table_row($text{'net_physical'},
		    &physical_input("physical", &get_default_physical()));

print &ui_table_row($text{'create_install'},
		    &ui_yesno_radio("install", 0));

print &ui_table_row($text{'create_webmin'},
		    &ui_yesno_radio("webmin", 0));
		    
print &ui_table_row($text{'pkg_inherit'},
			&ui_yesno_radio("inherit", 0));

print &ui_table_row($text{'create_pkgs'},
		    &ui_textarea("pkgs", undef, 5, 50));

print &ui_table_hr();

print &ui_table_row($text{'create_cfg'},
		    &ui_radio("cfg", 1, [ [ 1, $text{'create_cfgyes'} ],
					  [ 0, $text{'create_cfgno'} ] ]));

print &ui_table_row($text{'create_hostname'},
		    &ui_opt_textbox("hostname", undef, 20,
				$text{'create_samehost'}));

print &ui_table_row($text{'create_root'},
		    &ui_opt_textbox("root", undef, 15, $text{'create_same'}));

$tz = &time::get_current_timezone();
print &ui_table_row($text{'create_timezone'},
		    &ui_opt_textbox("timezone", undef, 25,
				    &text('create_same2', $tz)));

$locale = &get_global_locale();
print &ui_table_row($text{'create_locale'},
		    &ui_opt_textbox("locale", undef, 10,
			    &text('create_same2', $locale)));

print &ui_table_row($text{'create_terminal'},
		    &ui_opt_textbox("terminal", undef, 10,
				    $text{'create_vt100'}));

$dns = &net::get_dns_config();
($resolv) = grep { $_ ne "files" } split(/\s+/, $dns->{'order'});
$resolv ||= "none";
print &ui_table_row($text{'create_name'},
	    &ui_radio("resolv", $resolv, [ [ "none", $text{'create_none'} ],
				       [ "dns", $text{'create_dns'} ],
				       [ "nis", $text{'create_nis'} ],
				       [ "nis+", $text{'create_nis+'} ],
				     ]));

$domain = $resolv eq "dns" ? $dns->{'domain'}->[0] :
	  $resolv eq "nis" || $resolv eq "nis+" ? &net::get_domainname()
						: undef;
print &ui_table_row($text{'create_domain'},
		    &ui_textbox("domain", $domain, 20));

if ($resolv eq "dns") {
	@servers = map { &to_hostname($_) || $_ }
			 @{$dns->{'nameserver'}};
	$server = join(" ", @servers);
	}
elsif ($resolv eq "nis" || $resolv eq "nis+") {
	$server = `ypwhich`;
	chop($server);
	}
print &ui_table_row($text{'create_server'},
		    &ui_textbox("server", $server, 40));

($router) = &net::get_default_gateway();
if (!$router) {
	# Use active settings
	foreach $r (&net::list_routes()) {
		$router = $r->{'gateway'} if ($r->{'dest'} eq '0.0.0.0');
		}
	}
print &ui_table_row($text{'create_router'},
		    &ui_opt_textbox("router", $router, 20,
				    $text{'create_none'}));

print &ui_table_end();
print &ui_form_end([ [ "ok", $text{'create_ok'} ] ]);

&ui_print_footer("index.cgi", $text{'index_return'});

