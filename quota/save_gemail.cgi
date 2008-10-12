#!/usr/local/bin/perl
# Save scheduled email settings for groups

require './quota-lib.pl';
$access{'email'} && &can_edit_filesys($in{'filesys'}) ||
	&error($text{'email_ecannot'});
&ReadParse();
&error_setup($text{'email_err'});

# Validate inputs
if ($in{'email'}) {
	$in{'interval'} =~ /^[0-9\.]+$/ || &error($text{'email_einterval'});
	$in{'percent'} =~ /^[0-9\.]+$/ || &error($text{'email_epercent'});
	$in{'from'} =~ /^\S+$/i || &error($text{'email_efrom'});
	$in{'tomode'} != 1 || $in{'to'} =~ /^\S+$/ ||
		&error($text{'email_eto'});
	$in{'cc_def'} || $in{'cc'} =~ /^\S+$/i || &error($text{'email_ecc'});
	}

# Save settings
&lock_file($module_config_file);
$config{"gemail_".$in{'filesys'}} = $in{'email'};
$config{"gemail_interval_".$in{'filesys'}} = $in{'interval'};
$config{"gemail_type_".$in{'filesys'}} = $in{'type'};
$config{"gemail_percent_".$in{'filesys'}} = $in{'percent'};
$config{"gemail_from_".$in{'filesys'}} = $in{'from'};
$config{"gemail_to_".$in{'filesys'}} = $in{'to'};
$config{"gemail_tomode_".$in{'filesys'}} = $in{'tomode'};
$config{"gemail_cc_".$in{'filesys'}} = $in{'cc'};
&save_module_config();
&unlock_file($module_config_file);

# Create cron job, if needed
if ($in{'email'}) {
	&create_email_job();
	}

&webmin_log("email", "group", $in{'filesys'}, \%in);
&redirect("list_groups.cgi?dir=".&urlize($in{'filesys'}));

