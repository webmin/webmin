#!/usr/local/bin/perl
# save_priv.cgi
# Save privileged options

require './spam-lib.pl';
&error_setup($text{'priv_err'});
&ReadParse();
&set_config_file_in(\%in);
&can_use_check("priv");
&execute_before("priv");
&lock_spam_files();
$conf = &get_config();

&parse_opt($conf, "auto_whitelist_path", \&check_path);
&parse_opt($conf, "auto_whitelist_file_mode", \&check_mode);
&parse_opt($conf, "dcc_options", \&check_args);
&parse_opt($conf, "timelog_path", \&check_path);
&parse_opt($conf, "razor_config", \&check_path);

&flush_file_lines();
&unlock_spam_files();
&execute_after("priv");
&webmin_log("priv");
&redirect($redirect_url);

sub check_path
{
$_[0] =~ /^(\/|\~)\S+$/ || &error(&text('priv_epath', $_[0]));
}

sub check_mode
{
$_[0] =~ /^[0-7]{4}$/ || &error(&text('priv_emode', $_[0]));
}

sub check_args
{
$_[0] =~ /^[A-Za-z \-]+$/ || &error(&text('priv_eargs', $_[0]));
}

