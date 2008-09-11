#!/usr/local/bin/perl
# save_email.cgi
# Save scheduled email settings

require './quota-lib.pl';
$access{'email'} && &can_edit_filesys($in{'filesys'}) ||
	&error($text{'email_ecannot'});
&ReadParse();
&error_setup($text{'email_err'});

# Validate inputs
if ($in{'email'}) {
	$in{'interval'} =~ /^[0-9\.]+$/ || &error($text{'email_einterval'});
	$in{'percent'} =~ /^[0-9\.]+$/ || &error($text{'email_epercent'});
	$in{'domain'} =~ /^[a-z0-9\.\-]+$/i || &error($text{'email_edomain'});
	$in{'from'} =~ /^\S+$/i || &error($text{'email_efrom'});
	$in{'cc_def'} || $in{'cc'} =~ /^\S+$/i || &error($text{'email_ecc'});
	}

# Save settings
&lock_file($module_config_file);
$config{"email_".$in{'filesys'}} = $in{'email'};
$config{"email_interval_".$in{'filesys'}} = $in{'interval'};
$config{"email_type_".$in{'filesys'}} = $in{'type'};
$config{"email_percent_".$in{'filesys'}} = $in{'percent'};
$config{"email_domain_".$in{'filesys'}} = $in{'domain'};
$config{"email_virtualmin_".$in{'filesys'}} = $in{'virtualmin'};
$config{"email_from_".$in{'filesys'}} = $in{'from'};
$config{"email_cc_".$in{'filesys'}} = $in{'cc'};
&save_module_config();
&unlock_file($module_config_file);

# Create cron job, if needed
if ($in{'email'}) {
	&create_email_job();
	}

&webmin_log("email", "user", $in{'filesys'}, \%in);
&redirect("list_users.cgi?dir=".&urlize($in{'filesys'}));

