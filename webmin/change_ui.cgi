#!/usr/local/bin/perl
# change_ui.cgi
# Change colour scheme

require './webmin-lib.pl';
&error_setup($text{'ui_err'});
&ReadParse();

&lock_file("$config_directory/config");
for($i=0; $i<@cs_names; $i++) {
	$cd = $cs_codes[$i];
	if ($in{"${cd}_def"}) { delete($gconfig{$cd}); }
	elsif ($in{$cd} !~ /^[0-9a-fA-F]{6}$/) {
		&error(&text('ui_ergb', $cs_names[$i]));
		}
	else { $gconfig{$cd} = $in{$cd}; }
	}

$gconfig{'sysinfo'} = $in{'sysinfo'};
$gconfig{'showlogin'} = $in{'showlogin'};
$gconfig{'showhost'} = $in{'showhost'};
$gconfig{'hostnamemode'} = $in{'hostnamemode'};
$in{'hostnamemode'} != 3 || $in{'hostnamedisplay'} =~ /^[a-z0-9\.\_\-]+$/i ||
	&error($text{'ui_ehostnamedisplay'});
$gconfig{'hostnamedisplay'} = $in{'hostnamedisplay'};
$gconfig{'feedback_to'} = $in{'feedback_def'} ? undef : $in{'feedback'};
$gconfig{'nofeedbackcc'} = $in{'nofeedbackcc'};
$gconfig{'dateformat'} = $in{'dateformat'};

$in{'width_def'} || $in{'width'} =~ /^\d+$/ || &error($text{'ui_ewidth'});
$gconfig{'help_width'} = $in{'width'};
$in{'height_def'} || $in{'height'} =~ /^\d+$/ || &error($text{'ui_eheight'});
$gconfig{'help_height'} = $in{'height'};

# Save dialog box sizes
foreach $db ("file", "user", "users", "date", "module", "modules") {
	if ($in{"size".$db."_def"}) {
		delete($gconfig{"db_size".$db});
		}
	else {
		$in{"size".$db."_w"} =~ /^\d+$/ ||
			&error($text{'ui_edbwidth'});
		$in{"size".$db."_h"} =~ /^\d+$/ ||
			&error($text{'ui_edbheight'});
		$gconfig{"db_size".$db} = $in{"size".$db."_w"}."x".
					  $in{"size".$db."_h"};
		}
	}

&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");
&webmin_log('ui', undef, undef, \%in);
&redirect("");

