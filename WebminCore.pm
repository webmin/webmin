=head1 WebminCore.pm

Perl module that exports Webmin API functions. Example code :

  use WebminCore;
  init_config();
  ui_print_header(undef, 'My Module', '');
  print 'This is Webmin version ',get_webmin_version(),'<p>\n';
  ui_print_footer();

Full function documentation is in web-lib-funcs.pl.

=cut

$main::export_to_caller = 1;
package WebminCore;
require Exporter;
@ISA = qw(Exporter);

# Add functions in web-lib-funcs.pl
# Generated with :
# grep -h "^sub " web-lib-funcs.pl ui-lib.pl | sed -e 's/sub /\&/' | xargs echo
@EXPORT = qw(&read_file &read_file_cached &read_file_cached_with_stat &write_file &html_escape &quote_escape &tempname &transname &trunc &indexof &indexoflc &sysprint &check_ipaddress &check_ip6address &generate_icon &urlize &un_urlize &include &copydata &ReadParseMime &ReadParse &read_fully &read_parse_mime_callback &read_parse_mime_javascript &PrintHeader &header &get_html_title &get_html_framed_title &get_html_status_line &popup_header &footer &popup_footer &load_theme_library &redirect &kill_byname &kill_byname_logged &find_byname &error &popup_error &error_setup &wait_for &fast_wait_for &has_command &make_date &file_chooser_button &popup_window_button &read_acl &acl_filename &acl_check &get_miniserv_config &put_miniserv_config &restart_miniserv &reload_miniserv &check_os_support &http_download &complete_http_download &http_post &ftp_download &ftp_upload &no_proxy &open_socket &download_timeout &ftp_command &to_ipaddress &to_ip6address &to_hostname &icons_table &replace_file_line &read_file_lines &flush_file_lines &unflush_file_lines &unix_user_input &unix_group_input &hlink &user_chooser_button &group_chooser_button &foreign_check &foreign_exists &foreign_available &foreign_require &foreign_call &foreign_config &foreign_installed &foreign_defined &get_system_hostname &get_webmin_version &get_module_acl &get_group_module_acl &save_module_acl &save_group_module_acl &init_config &load_language &text_subs &text &encode_base64 &decode_base64 &get_module_info &get_all_module_infos &list_themes &get_theme_info &list_languages &read_env_file &write_env_file &lock_file &unlock_file &test_lock &unlock_all_files &can_lock_file &webmin_log &additional_log &webmin_debug_log &system_logged &backquote_logged &backquote_with_timeout &backquote_command &kill_logged &rename_logged &rename_file &symlink_logged &symlink_file &link_file &make_dir &set_ownership_permissions &unlink_logged &unlink_file &copy_source_dest &remote_session_name &remote_foreign_require &remote_foreign_call &remote_foreign_check &remote_foreign_config &remote_eval &remote_write &remote_read &remote_finished &remote_error_setup &remote_rpc_call &remote_multi_callback &remote_multi_callback_error &serialise_variable &unserialise_variable &other_groups &date_chooser_button &help_file &seed_random &disk_usage_kb &recursive_disk_usage &help_search_link &make_http_connection &read_http_connection &write_http_connection &close_http_connection &clean_environment &reset_environment &clean_language &progress_callback &switch_to_remote_user &switch_to_unix_user &create_user_config_dirs &create_missing_homedir &filter_javascript &resolve_links &simplify_path &same_file &flush_webmin_caches &list_usermods &available_usermods &get_available_module_infos &get_visible_module_infos &get_visible_modules_categories &is_under_directory &parse_http_url &check_clicks_function &load_entities_map &entities_to_ascii &get_product_name &get_charset &get_display_hostname &save_module_config &save_user_module_config &nice_size &get_perl_path &get_goto_module &select_all_link &select_invert_link &select_rows_link &check_pid_file &get_mod_lib &module_root_directory &list_mime_types &guess_mime_type &open_tempfile &close_tempfile &print_tempfile &is_selinux_enabled &get_clear_file_attributes &reset_file_attributes &cleanup_tempnames &open_lock_tempfile &END &month_to_number &number_to_month &get_rbac_module_acl &supports_rbac &supports_ipv6 &use_rbac_module_acl &execute_command &open_readfile &open_execute_command &translate_filename &translate_command &register_filename_callback &register_command_callback &capture_function_output &capture_function_output_tempfile &modules_chooser_button &substitute_template &running_in_zone &running_in_vserver &running_in_xen &running_in_openvz &list_categories &is_readonly_mode &command_as_user &list_osdn_mirrors &convert_osdn_url &get_current_dir &supports_users &supports_symlinks &quote_path &get_windows_root &read_file_contents &unix_crypt &split_quoted_string &write_to_http_cache &check_in_http_cache &supports_javascript &ui_table_start &ui_table_end &ui_table_row &ui_table_hr &ui_table_span &ui_columns_start &ui_columns_row &ui_columns_header &ui_checked_columns_row &ui_radio_columns_row &ui_columns_end &ui_columns_table &ui_form_columns_table &ui_form_start &ui_form_end &ui_textbox &ui_filebox &ui_bytesbox &ui_upload &ui_password &ui_hidden &ui_select &ui_multi_select &ui_multi_select_javascript &ui_radio &ui_yesno_radio &ui_checkbox &ui_oneradio &ui_textarea &ui_user_textbox &ui_group_textbox &ui_opt_textbox &ui_submit &ui_reset &ui_button &ui_date_input &ui_buttons_start &ui_buttons_end &ui_buttons_row &ui_buttons_hr &ui_post_header &ui_pre_footer &ui_print_header &ui_print_unbuffered_header &ui_print_footer &ui_config_link &ui_print_endpage &ui_subheading &ui_links_row &ui_hidden_javascript &ui_hidden_start &ui_hidden_end &ui_hidden_table_row_start &ui_hidden_table_row_end &ui_hidden_table_start &ui_hidden_table_end &ui_tabs_start &ui_tabs_end &ui_tabs_start_tab &ui_tabs_start_tabletab &ui_tabs_end_tab &ui_tabs_end_tabletab &ui_max_text_width &ui_radio_selector &ui_radio_selector_javascript &ui_grid_table &ui_radio_table &ui_up_down_arrows &ui_hr &ui_nav_link &ui_confirmation_form &js_disable_inputs &ui_page_flipper &js_checkbox_disable &js_redirect &get_module_name clear_time_locale reset_time_locale eval_as_unix_user get_userdb_string connect_userdb disconnect_userdb split_userdb_string uniquelc);

# Add global variables in web-lib.pl
push(@EXPORT, qw(&unique));
push(@EXPORT, qw($config_directory $var_directory $remote_error_handler %month_to_number_map %number_to_month_map $webmin_feedback_address $default_lang $default_charset $module_index_name $module_index_link %in $in @in $progress_callback_prefix $progress_callback_url $wait_for_debug $wait_for_input @matches $theme_no_table $webmin_logfile $pragma_no_cache));

# Functions defined in themes
push(@EXPORT, qw(&theme_post_save_domain &theme_post_save_domains &theme_post_save_server &theme_select_server &theme_select_domain &theme_post_save_folder &theme_post_change_modules &theme_address_button &theme_virtualmin_ui_rating_selector &theme_virtualmin_ui_show_cron_time &theme_virtualmin_ui_parse_cron_time &theme_virtualmin_ui_html_editor_bodytags &theme_virtualmin_ui_show_html_editor));

$called_from_webmin_core = 1;
do "web-lib.pl";
do "ui-lib.pl";

1;

