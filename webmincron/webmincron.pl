#!/usr/local/bin/perl
# Wrapper to run a single function via webmin cron

$main::no_acl_check = 1;
$main::no_referers_check = 1;
do './webmincron-lib.pl';
$cron = $ARGV[0];

# Require the module, call the function
&foreign_require($cron->{'module'}, $cron->{'file'});
for($i=0; defined($cron->{'arg'.$i}); $i++) {
	push(@args, $cron->{'arg'.$i});
	}
&foreign_call($cron->{'module'}, $cron->{'func'}, @args);
