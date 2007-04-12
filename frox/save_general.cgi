#!/usr/local/bin/perl
# Save general options

require './frox-lib.pl';
&ReadParse();
&error_setup($text{'general_err'});
$conf = &get_config();

&save_user($conf, "User");
&save_group($conf, "Group");
&save_textbox($conf, "WorkingDir", \&check_dir);
&save_yesno($conf, "DontChroot");
&save_opt_textbox($conf, "LogLevel", \&check_level);
&save_opt_textbox($conf, "PidFile", \&check_pidfile);

&lock_file($config{'frox_conf'});
&flush_file_lines();
&unlock_file($config{'frox_conf'});
&webmin_log("general");
&redirect("");

sub check_dir
{
return -d $_[0] ? undef : $text{'general_edir'};
}

sub check_level
{
return $_[0] =~ /^\d+$/ ? undef : $text{'general_elevel'};
}

sub check_pidfile
{
return $_[0] =~ /^\/\S+$/ ? undef : $text{'general_epidfile'};
}
