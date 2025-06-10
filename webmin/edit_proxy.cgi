#!/usr/local/bin/perl
# edit_proxy.cgi
# Proxy servers config form

require './webmin-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'proxy_title'}, "");

# Show tabs
@tabs = ( [ "proxy", $text{'proxy_tabproxy'}, "edit_proxy.cgi?mode=proxy" ],
	  [ "down", $text{'proxy_tabdown'}, "edit_proxy.cgi?mode=down" ] );
print &ui_tabs_start(\@tabs, "pd", $in{'mode'} || "proxy", 1);

print &ui_tabs_start_tab("pd", "proxy");
print $text{'proxy_desc'},"<p>\n";
print &ui_form_start("change_proxy.cgi", "post");
print &ui_table_start($text{'proxy_header'}, undef, 2, [ "width=30%" ]);

# HTTP proxy
print &ui_table_row($text{'proxy_http'},
	&ui_opt_textbox("http", $gconfig{'http_proxy'}, 50,
			$text{'proxy_none'}), undef, [ "valign=middle","valign=middle" ]);

# FTP proxy
print &ui_table_row($text{'proxy_ftp'},
	&ui_opt_textbox("ftp", $gconfig{'ftp_proxy'}, 50,
			$text{'proxy_none'}), undef, [ "valign=middle","valign=middle" ]);

# No proxy for domains
print &ui_table_row($text{'proxy_nofor'},
	&ui_textbox("noproxy", $gconfig{'noproxy'}, 60), undef, [ "valign=middle","valign=middle" ]);

# User and password
print &ui_table_row($text{'proxy_user'},
	&ui_textbox("puser", $gconfig{'proxy_user'}, 20), undef, [ "valign=middle","valign=middle" ]);
print &ui_table_row($text{'proxy_pass'},
	&ui_password("ppass", $gconfig{'proxy_pass'}, 20), undef, [ "valign=middle","valign=middle" ]);

# Bind to address for outgoing connections
print &ui_table_row($text{'proxy_bind'},
	&ui_opt_textbox("bind", $gconfig{'bind_proxy'}, 35, $text{'default'}), undef, [ "valign=middle","valign=middle" ]);

# Fallback to direct
print &ui_table_row($text{'proxy_fallback'},
	&ui_yesno_radio("fallback", int($gconfig{'proxy_fallback'})), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);
print &ui_tabs_end_tab();

# OSDN mirror form
print &ui_tabs_start_tab("pd", "down");
print $text{'proxy_desc2'},"<p>\n";
print &ui_form_start("change_osdn.cgi");
print &ui_table_start($text{'proxy_header2'}, undef, 2);

# Cache size
print &ui_table_row($text{'proxy_cache'},
		    &ui_radio("cache_def", $gconfig{'cache_size'} ? 0 : 1,
			      [ [ 1, $text{'proxy_cache1'} ],
				[ 0, $text{'proxy_cache0'} ] ])."\n".
		    &ui_bytesbox("cache", $gconfig{'cache_size'}, 8), undef, [ "valign=middle","valign=middle" ]);

# Cache time
print &ui_table_row($text{'proxy_daysmax'},
		    &ui_opt_textbox("days", $gconfig{'cache_days'}, 5,
			    $text{'proxy_daysdef'})." ".$text{'proxy_days'}, undef, [ "valign=middle","valign=middle" ]);

# Modules to cache in
$excl = ($gconfig{'cache_mods'} =~ s/^\!//);
@mods = split(/\s+/, $gconfig{'cache_mods'});
print &ui_table_row($text{'proxy_mods'},
		    &ui_radio("mods_def", !$gconfig{'cache_mods'} ? 0 :
					  $excl ? 2 : 1,
			      [ [ 0, $text{'proxy_mods0'} ],
				[ 1, $text{'proxy_mods1'} ],
				[ 2, $text{'proxy_mods2'} ] ])."<br>\n".
		    &ui_select("mods", \@mods,
			       [ map { [ $_->{'dir'}, $_->{'desc'} ] }
				  sort { lc($a->{'desc'}) cmp lc($b->{'desc'}) }
				   &get_all_module_infos() ],
			       10, 1));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ],
		     [ "clear", $text{'proxy_clear'} ] ]);

@cached = &list_cached_files();
if (@cached) {
	# Show cache management and clearing buttons
	print &ui_hr();
	print &ui_buttons_start();
	print &ui_buttons_row("cache.cgi", $text{'proxy_cacheb'},
					   $text{'proxy_cachebdesc'});
	$sz = &nice_size(&disk_usage_kb($main::http_cache_directory)*1024);
	print &ui_buttons_row("clear_cache.cgi", $text{'proxy_clear'},
			      &text('proxy_cleardesc', scalar(@cached), $sz));
	print &ui_buttons_end();
	}
print &ui_tabs_end_tab();

print &ui_tabs_end(1);

&ui_print_footer("", $text{'index_return'});

