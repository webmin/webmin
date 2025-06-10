#!/usr/local/bin/perl
# Show options for report style

require './sarg-lib.pl';

$conf = &get_config();
&ui_print_header(undef, $text{'report_title'}, "");
print &ui_form_start("save_report.cgi", "post");
print &ui_table_start($text{'report_header'}, "width=100%", 4);
$config_prefix = "report_";

print &config_select($conf, "report_type",
		     [ [ "topusers", $text{'report_topusers'} ],
		       [ "topsites", $text{'report_topsites'} ],
		       [ "sites_users", $text{'report_sites_users'} ],
		       [ "users_sites", $text{'report_users_sites'} ],
		       [ "date_time", $text{'report_date_time'} ],
		       [ "denied", $text{'report_denied'} ],
		       [ "auth_failures", $text{'report_auth_failures'} ],
		       [ "site_user_time_date", $text{'report_site_user_time_date'} ],
		       [ "downloads", $text{'report_downloads'} ] ],
		     $text{'report_all'}, 3);

print &ui_table_hr();

print &config_yesno($conf, "resolve_ip", undef, undef, undef, 3);
print &config_yesno($conf, "user_ip", undef, undef, undef, 3);

print &config_radio($conf, "records_without_userid",
		    [ [ "ignore", $text{'report_ignore'} ],
		      [ "ip", $text{'report_ip'} ],
		      [ "everybody", $text{'report_everybody'} ] ], 3);

print &ui_table_hr();

print &config_sortfield($conf, "user_sort_field",
			[ "USER", "CONNECT", "BYTES", "TIME" ]);
print &config_sortfield($conf, "topuser_sort_field",
			[ "SITE", "CONNECT", "BYTES", "TIME" ]);
print &config_sortfield($conf, "topsites_sort_order",
			[ "CONNECT", "BYTES" ],
			[ [ "A", $text{'report_sorta'} ],
			  [ "D", $text{'report_sortd'} ] ]);
print &config_radio($conf, "index_sort_order",
		    [ [ "A", $text{'report_sorta'} ],
		      [ "D", $text{'report_sortd'} ] ], 3);

print &ui_table_hr();

print &config_opt_textbox($conf, "exclude_users", 40, 3);
print &config_opt_textbox($conf, "exclude_hosts", 40, 3);
print &config_opt_textbox($conf, "exclude_codes", 40, 3);
print &config_opt_textbox($conf, "usertab", 40, 3);
print &config_colons($conf, "include_users", ":", $text{'report_nostrings'}, 3);
print &config_colons($conf, "exclude_string", ":", $text{'report_allusers'}, 3);

print &ui_table_hr();

print &config_yesno($conf, "index", undef, undef,
		    [ [ "only", $text{'report_only'} ] ], 3);
print &config_yesno($conf, "overwrite_report", undef, $text{'report_overno'},
		    undef, 3);

print &config_yesno($conf, "use_comma", undef, undef, undef, 3);

print &config_opt_textbox($conf, "topsites_num", 5, 3);

print &config_opt_textbox($conf, "topuser_num", 5, 3);

print &config_opt_textbox($conf, "max_elapsed", 5, 3);

print &config_yesno($conf, "long_url", undef, undef, undef, 3);

print &config_radio($conf, "date_time_by",
		    [ [ "bytes", $text{'report_bytes'} ],
		      [ "elap", $text{'report_elap'} ] ], 3);

print &config_radio($conf, "site_user_time_date_type",
		    [ [ "table", $text{'report_table'} ],
		      [ "list", $text{'report_list'} ] ], 3);

print &config_radio($conf, "displayed_values",
		    [ [ "bytes", $text{'report_bytes2'} ],
		      [ "abbreviation", $text{'report_abbrev'} ] ], 3);

print &config_opt_textbox($conf, "user_invalid_char", 10, 3);

print &ui_table_hr();

print &config_yesno($conf, "privacy", undef, undef, undef, 3);
print &config_opt_textbox($conf, "privacy_string", 25, 3);
print &config_opt_textbox($conf, "privacy_string_color", 20, 3);

print &ui_table_hr();

print &config_range($conf, "weekdays", 0, 6, 3);
print &config_range($conf, "hours", 0, 23, 3);

print &ui_table_end();
print &ui_form_end([ [ 'save', $text{'save'} ] ], "100%");
&ui_print_footer("", $text{'index_return'});
