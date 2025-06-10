#!/usr/local/bin/perl
# Save report options

require './sarg-lib.pl';
&ReadParse();
$conf = &get_config();
$config_prefix = "report_";
&error_setup($text{'report_err'});

&lock_sarg_files();
&save_select($conf, "report_type");
&save_yesno($conf, "resolve_ip");
&save_yesno($conf, "user_ip");
&save_radio($conf, "records_without_userid");

&save_sortfield($conf, "user_sort_field");
&save_sortfield($conf, "topuser_sort_field");
&save_sortfield($conf, "topsites_sort_order");
&save_radio($conf, "index_sort_order");

&save_opt_textbox($conf, "exclude_users", \&check_file);
&save_opt_textbox($conf, "exclude_hosts", \&check_file);
&save_opt_textbox($conf, "exclude_codes", \&check_file);
&save_opt_textbox($conf, "usertab", \&check_file);

&save_colons($conf, "include_users", ":");
&save_colons($conf, "exclude_string", ":");

&save_yesno($conf, "index");
&save_yesno($conf, "overwrite_report");
&save_yesno($conf, "use_comma");
&save_opt_textbox($conf, "topsites_num", \&check_num);
&save_opt_textbox($conf, "topuser_num", \&check_num);
&save_opt_textbox($conf, "max_elapsed", \&check_num);
&save_yesno($conf, "long_url");
&save_radio($conf, "date_time_by");
&save_radio($conf, "site_user_time_date_type");
&save_radio($conf, "displayed_values");
&save_opt_textbox($conf, "user_invalid_char", \&check_char);

&save_yesno($conf, "privacy");
&save_opt_textbox($conf, "privacy_string", \&check_string);
&save_opt_textbox($conf, "privacy_string_color", \&check_colour);

&save_range($conf, "weekdays");
&save_range($conf, "hours");

&flush_file_lines();
&unlock_sarg_files();
&webmin_log("report");
&redirect("");

sub check_file
{
return -r $_[0] ? undef : $text{'report_efile'};
}

sub check_num
{
return $_[0] =~ /^\d+$/ ? undef : $text{'report_enum'};
}

sub check_char
{
return $_[0] =~ /^\S+$/ ? undef : $text{'report_echar'};
}

sub check_string
{
return $_[0] =~ /^\S+$/ ? undef : $text{'report_estring'};
}

sub check_colour
{
return $_[0] =~ /^\S+$/ ? undef : $text{'style_ecolour'};
}
