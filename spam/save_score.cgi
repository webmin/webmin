#!/usr/local/bin/perl
# save_score.cgi
# Save message scoring options

require './spam-lib.pl';
&error_setup($text{'score_err'});
&ReadParse();
&set_config_file_in(\%in);
&can_use_check("score");
&execute_before("score");
&lock_spam_files();
$conf = &get_config();

$hits_param = &version_atleast(3.0) ? "required_score" : "required_hits";
&parse_opt($conf, $hits_param, \&hits_check);
&parse_opt($conf, "auto_whitelist_factor", \&auto_check);
&parse_yes_no($conf, "use_bayes");
&parse_opt($conf, "check_mx_attempts", \&mx_check);
&parse_opt($conf, "check_mx_delay", \&mxdelay_check);
&parse_yes_no($conf, "skip_rbl_checks");
&parse_opt($conf, "rbl_timeout", \&timeout_check);
&parse_opt($conf, "num_check_received", \&received_check);

@trusted = grep { /\S/ } split(/\r?\n/, $in{'trusted_networks'});
&save_directives($conf, "trusted_networks", \@trusted, 1);

if (defined($in{'langs_def'})) {
	if ($in{'langs_def'} == 2) {
		&save_directives($conf, "ok_languages", [ ], 1);
		}
	elsif ($in{'langs_def'} == 1) {
		&save_directives($conf, "ok_languages", [ "all" ], 1);
		}
	else {
		&save_directives($conf, "ok_languages",
				 [ join(" ", split(/\0/, $in{'langs'})) ], 1);
		}
	}

if (defined($in{'locales_def'})) {
	if ($in{'locales_def'} == 2) {
		&save_directives($conf, "ok_locales", [ ], 1);
		}
	elsif ($in{'locales_def'} == 1) {
		&save_directives($conf, "ok_locales", [ "all" ], 1);
		}
	else {
		&save_directives($conf, "ok_locales",
				 [ join(" ", split(/\0/, $in{'locales'})) ], 1);
		}
	}

&flush_file_lines();
&unlock_spam_files();
&execute_after("score");
&webmin_log("score");
&redirect($redirect_url);

sub hits_check
{
$_[0] =~ /^\d+(\.\d+)?$/ || &error($text{'score_ehits'});
}

sub auto_check
{
$_[0] =~ /^\d+(\.\d+)?$/ && $_[0] >= 0 && $_[0] <= 1 ||
	&error($text{'score_eauto'});
}

sub mx_check
{
$_[0] =~ /^\d+$/ || &error($text{'score_emx'});
}

sub mxdelay_check
{
$_[0] =~ /^\d+$/ || &error($text{'score_emxdelay'});
}

sub timeout_check
{
$_[0] =~ /^\d+$/ || &error($text{'score_etimeout'});
}

sub received_check
{
$_[0] =~ /^\d+$/ || &error($text{'score_ereceived'});
}

