#!/usr/local/bin/perl
# Show caching options

require './frox-lib.pl';
&ui_print_header(undef, $text{'cache_title'}, "");
$conf = &get_config();

print &ui_form_start("save_cache.cgi", "post");
print &ui_table_start($text{'cache_header'}, "width=100%", 4);

$module = &find_value("CacheModule", $conf);
print &ui_table_row($text{'cache_module'},
		    &ui_radio("CacheModule", $module,
			      [ [ "", $text{'cache_none'} ],
				[ "local", $text{'cache_local'} ],
				[ "http", $text{'cache_http'} ] ]), 3, \@ui_td);

print &config_textbox($conf, "CacheSize", 6, undef, "MB");

print &config_textbox($conf, "HTTPProxy", 30);

print &ui_table_row("", "");

print &config_textbox($conf, "MinCacheSize", 6, undef, "bytes");

print &config_yesno($conf, "StrictCaching", undef, undef, "no");

print &config_yesno($conf, "CacheOnFQDN", undef, undef, "yes");

print &config_yesno($conf, "CacheAll", undef, undef, "no");

print &ui_table_hr();

print &config_opt_textbox($conf, "VirusScanner", 40, 3, $text{'cache_vnone'});

print &config_opt_textbox($conf, "VSOK", 4, 3);

print &config_opt_textbox($conf, "VSProgressMsgs", 4, 3);

print &ui_table_end();
print &ui_form_end([ [ 'save', $text{'save'} ] ], "100%");

&ui_print_footer("", $text{'index_return'});

