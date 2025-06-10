#!/usr/local/bin/perl
# Save options for report source and dest

require './sarg-lib.pl';
&ReadParse();
$conf = &get_config();
$config_prefix = "log_";
&error_setup($text{'log_err'});

&lock_sarg_files();
if ($in{'access_log_def'} == 0) {
	&save_directive($conf, "access_log", [ ]);
	}
elsif ($in{'access_log_def'} == 1) {
	&save_directive($conf, "access_log", [ $in{'squid_log'} ]);
	}
else {
	&save_textbox($conf, "access_log", \&check_log);
	}
&save_opt_textbox($conf, "output_dir", \&check_output_dir);
&save_opt_textbox($conf, "lastlog", \&check_lastlog);
&save_opt_textbox($conf, "useragent_log", \&check_log);
&save_opt_textbox($conf, "squidguard_log_path", \&check_log);
&save_opt_textbox($conf, "output_email", \&check_email);
&save_opt_textbox($conf, "mail_utility", \&check_mailx);

&flush_file_lines();
&unlock_sarg_files();
&webmin_log("log");
&redirect("");

sub check_log
{
return -r $_[0] ? undef : $text{'log_elog'};
}

sub check_output_dir
{
return -d $_[0] ? undef : $text{'log_edir'};
}

sub check_lastlog
{
return $_[0] =~ /^\d+$/ ? undef : $text{'log_elastlog'};
}

sub check_email
{
return $_[0] =~ /^\S+$/ ? undef : $text{'log_eemail'};
}

sub check_mailx
{
return $_[0] =~ /^(\S+)/ && &has_command($1) ? undef : $text{'log_emailx'};
}

