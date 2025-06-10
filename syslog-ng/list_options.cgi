#!/usr/local/bin/perl
# Show global options

require './syslog-ng-lib.pl';
$conf = &get_config();
$options = &find("options", $conf);
$options ||= { 'members' => [ ] };
$mems = $options->{'members'};
&ui_print_header(undef, $text{'options_title'}, "", "options");

print &ui_form_start("save_options.cgi", "post");
print &ui_table_start($text{'options_header'}, undef, 2);

$yesno = [ [ 'yes', $text{'yes'} ], [ 'no', $text{'no'} ],
	   [ '', $text{'default'} ] ];

# Hostname options
$use_fqdn = &find_value("use_fqdn", $options->{'members'});
print &ui_table_row($text{'options_use_fqdn'},
	  	    &ui_radio("use_fqdn", $use_fqdn, $yesno));

$check_hostname = &find_value("check_hostname", $options->{'members'});
print &ui_table_row($text{'options_check_hostname'},
	  	    &ui_radio("check_hostname", $check_hostname, $yesno));

$keep_hostname = &find_value("keep_hostname", $options->{'members'});
print &ui_table_row($text{'options_keep_hostname'},
	  	    &ui_radio("keep_hostname", $keep_hostname, $yesno));

$chain_hostnames = &find_value("chain_hostnames", $options->{'members'});
print &ui_table_row($text{'options_chain_hostnames'},
	  	    &ui_radio("chain_hostnames", $chain_hostnames, $yesno));

$bad_hostname = &find_value("bad_hostname", $options->{'members'});
print &ui_table_row($text{'options_bad_hostname'},
    &ui_opt_textbox("bad_hostname", $bad_hostname, 30, $text{'source_none'}));

print &ui_table_hr();

# DNS-related options
$use_dns = &find_value("use_dns", $options->{'members'});
print &ui_table_row($text{'options_use_dns'},
	  	    &ui_radio("use_dns", $use_dns, $yesno));

$dns_cache = &find_value("dns_cache", $options->{'members'});
print &ui_table_row($text{'options_dns_cache'},
	  	    &ui_radio("dns_cache", $dns_cache, $yesno));

$dns_cache_size = &find_value("dns_cache_size", $options->{'members'});
print &ui_table_row($text{'options_dns_cache_size'},
    &ui_opt_textbox("dns_cache_size", $dns_cache_size, 6, $text{'default'}).
    " ".$text{'options_entries'});

$dns_cache_expire = &find_value("dns_cache_expire", $options->{'members'});
print &ui_table_row($text{'options_dns_cache_expire'},
   &ui_opt_textbox("dns_cache_expire", $dns_cache_expire, 6, $text{'default'}).
   " ".$text{'options_secs'});

$dns_cache_expire_failed = &find_value("dns_cache_expire_failed", $options->{'members'});
print &ui_table_row($text{'options_dns_cache_expire_failed'},
   &ui_opt_textbox("dns_cache_expire_failed", $dns_cache_expire_failed, 6, $text{'default'})." ".$text{'options_secs'});


print &ui_table_hr();

# File and directory permission options
$owner = &find_value("owner", $options->{'members'});
print &ui_table_row($text{'options_owner'},
      &ui_opt_textbox("owner", $owner, 13, $text{'default'})." ".
      &user_chooser_button("owner"));

$group = &find_value("group", $options->{'members'});
print &ui_table_row($text{'options_group'},
      &ui_opt_textbox("group", $group, 13, $text{'default'})." ".
      &user_chooser_button("group"));

$perm = &find_value("perm", $options->{'members'});
print &ui_table_row($text{'options_perm'},
      &ui_opt_textbox("perm", $perm, 13, $text{'default'}));

$create_dirs = &find_value("create_dirs", $options->{'members'});
print &ui_table_row($text{'options_create_dirs'},
	  	    &ui_radio("create_dirs", $create_dirs, $yesno));

$dir_owner = &find_value("dir_owner", $options->{'members'});
print &ui_table_row($text{'options_dir_owner'},
      &ui_opt_textbox("dir_owner", $dir_owner, 13, $text{'default'})." ".
      &user_chooser_button("dir_owner"));

$dir_group = &find_value("dir_group", $options->{'members'});
print &ui_table_row($text{'options_dir_group'},
      &ui_opt_textbox("dir_group", $dir_group, 13, $text{'default'})." ".
      &user_chooser_button("dir_group"));

$dir_perm = &find_value("dir_perm", $options->{'members'});
print &ui_table_row($text{'options_dir_perm'},
      &ui_opt_textbox("dir_perm", $dir_perm, 13, $text{'default'}));

print &ui_table_hr();

# Other misc options
$time_reopen = &find_value("time_reopen", $options->{'members'});
print &ui_table_row($text{'options_time_reopen'},
      &ui_opt_textbox("time_reopen", $time_reopen, 6, $text{'default'}." (60)").
      " ".$text{'options_secs'});

$time_reap = &find_value("time_reap", $options->{'members'});
print &ui_table_row($text{'options_time_reap'},
      &ui_opt_textbox("time_reap", $time_reap, 6, $text{'default'}." (60)").
      " ".$text{'options_secs'});

$sync = &find_value("sync", $options->{'members'});
print &ui_table_row($text{'options_sync'},
      &ui_opt_textbox("sync", $sync, 6, $text{'default'}));

$stats = &find_value("stats", $options->{'members'});
print &ui_table_row($text{'options_stats'},
      &ui_opt_textbox("stats", $stats, 6, $text{'default'}." (600)").
      " ".$text{'options_secs'});

$log_fifo_size = &find_value("log_fifo_size", $options->{'members'});
print &ui_table_row($text{'options_log_fifo_size'},
      &ui_opt_textbox("log_fifo_size", $log_fifo_size, 6,
		      $text{'default'}." (100)"));

$use_time_recvd = &find_value("use_time_recvd", $options->{'members'});
print &ui_table_row($text{'options_use_time_recvd'},
	  	    &ui_radio("use_time_recvd", $use_time_recvd, $yesno));

$log_msg_size = &find_value("log_msg_size", $options->{'members'});
print &ui_table_row($text{'options_log_msg_size'},
      &ui_opt_textbox("log_msg_size", $log_msg_size, 6,
		      $text{'default'}." (2048)")." bytes");

$sanitize_filenames = &find_value("sanitize_filenames", $options->{'members'});
print &ui_table_row($text{'options_sanitize_filenames'},
		  &ui_radio("sanitize_filenames", $sanitize_filenames, $yesno));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
