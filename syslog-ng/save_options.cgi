#!/usr/local/bin/perl
# Update global options

require './syslog-ng-lib.pl';
&ReadParse();
$conf = &get_config();
$options = &find("options", $conf);
$options ||= { 'name' => 'options',
	       'type' => 1,
	       'values' => [ ],
	       'members' => [ ] };
$mems = $options->{'members'};
&error_setup($text{'options_err'});

# Validate and store inputs
&save_yesno_option("use_fqdn");
&save_yesno_option("check_hostname");
&save_yesno_option("keep_hostname");
&save_yesno_option("chain_hostnames");
&save_optional_option("bad_hostname", '\S');

&save_yesno_option("use_dns");
&save_yesno_option("dns_cache");
&save_optional_option("dns_cache_size", '^\d+$');
&save_optional_option("dns_cache_expire", '^\d+$');
&save_optional_option("dns_cache_expire_failed", '^\d+$');

&save_optional_option("owner", '\S');
&save_optional_option("group", '\S');
&save_optional_option("perm", '^[0-7]+$');
&save_yesno_option("create_dirs");
&save_optional_option("dir_owner", '\S');
&save_optional_option("dir_group", '\S');
&save_optional_option("dir_perm", '^[0-7]+$');

&save_optional_option("time_reopen", '^\d+$');
&save_optional_option("time_reap", '^\d+$');
&save_optional_option("sync", '^\d+$');
&save_optional_option("stats", '^\d+$');
&save_optional_option("log_fifo_size", '^\d+$');
&save_yesno_option("use_time_recvd");
&save_optional_option("log_msg_size", '^\d+$');
&save_yesno_option("sanitize_filenames");

# Write out options section
&lock_all_files($conf);
&save_directive($conf, undef, "options", $options, 0);
&unlock_all_files();
&webmin_log("options");

&redirect("");

sub save_yesno_option
{
local ($name) = @_;
local $dir = $in{$name} ?
	{ 'name' => $name,
	  'type' => 0,
	  'values' => [ $in{$name} ] } : undef;
&save_directive($conf, $options, $name, $dir, 1);
}

sub save_optional_option
{
local ($name, $re) = @_;
if ($in{$name."_def"}) {
	&save_directive($conf, $options, $name, undef, 1);
	}
else {
	!$re || $in{$name} =~ /$re/ || &error($text{'options_e'.$name});
	local $dir = { 'name' => $name,
		       'type' => 0,
		       'values' => [ $in{$name} ] };
	&save_directive($conf, $options, $name, $dir, 1);
	}
}

