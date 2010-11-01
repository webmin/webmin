#!/usr/local/bin/perl
# change_ui.cgi
# Change colour scheme

require './usermin-lib.pl';
$access{'ui'} || &error($text{'acl_ecannot'});
&error_setup($text{'ui_err'});
&ReadParse();
$in{'feedback_def'} || $in{'feedback'} =~ /\S/ || &error($text{'ui_efeedback'});
$in{'feedbackmail_def'} || &to_ipaddress($in{'feedbackmail'}) ||
    &to_ip6address($in{'feedbackmail'}) || &error($text{'ui_efeedbackmail'});
$in{'feedbackhost_def'} || $in{'feedbackhost'} =~ /^\S+$/ ||
	&error($text{'ui_efeedbackhost'});

&lock_file($usermin_config);
&get_usermin_config(\%uconfig);
for($i=0; $i<@webmin::cs_names; $i++) {
	$cd = $webmin::cs_codes[$i];
	if ($in{"${cd}_def"}) { delete($uconfig{$cd}); }
	elsif ($in{"${cd}"} !~ /^[0-9a-fA-F]{6}$/) {
		&error(&text('ui_ergb', $webmin::cs_names[$i] . $in{"${cd}_rgb"}));
		}
	else { $uconfig{$cd} = $in{"${cd}"}; }
	}
$uconfig{'texttitles'} = $in{'texttitles'};
$uconfig{'sysinfo'} = $in{'sysinfo'};
$uconfig{'feedback'} = $in{'feedback_def'} ? undef : $in{'feedback'};
$uconfig{'feedbackmail'} = $in{'feedbackmail_def'} ? undef :$in{'feedbackmail'};
$uconfig{'feedbackhost'} = $in{'feedbackhost_def'} ? undef :$in{'feedbackhost'};
$uconfig{'gotoone'} = $in{'gotoone'};
$uconfig{'gotomodule'} = $in{'gotomodule'};
$uconfig{'nohostname'} = $in{'nohostname'};
$uconfig{'showlogin'} = $in{'showlogin'};
$uconfig{'hostnamemode'} = $in{'hostnamemode'};
$uconfig{'hostnamedisplay'} = $in{'hostnamedisplay'};
$uconfig{'notabs'} = $in{'notabs'};
$uconfig{'dateformat'} = $in{'dateformat'};
&write_file($usermin_config, \%uconfig);
&unlock_file($usermin_config);
&webmin_log('ui', undef, undef, \%in);
&redirect("");

