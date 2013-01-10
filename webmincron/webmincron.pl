#!/usr/local/bin/perl
# Wrapper to run a single function via webmin cron

$main::no_acl_check = 1;
$main::no_referers_check = 1;
$main::webmin_script_type = 'cron';
do './webmincron-lib.pl';
$cron = $ARGV[0];

# Require the module, call the function
&foreign_require($cron->{'module'}, $cron->{'file'});
if ($cron->{'args'}) {
	&foreign_call($cron->{'module'}, $cron->{'func'},
		      @{$cron->{'args'}});
	}
else {
	&foreign_call($cron->{'module'}, $cron->{'func'});
	}
