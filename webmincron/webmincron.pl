#!/usr/local/bin/perl
# Wrapper to run a single function via webmin cron

$main::no_acl_check = 1;
$main::no_referers_check = 1;
$main::webmin_script_type = 'cron';
do './webmincron-lib.pl';
$cron = $ARGV[0];

# Build list of args
my @args;
for(my $i=0; defined($cron->{'arg'.$i}); $i++) {
	push(@args, $cron->{'arg'.$i});
	}

# Force webmin script type to be cron
$main::webmin_script_type = 'cron';

# Require the module, call the function
&foreign_require($cron->{'module'}, $cron->{'file'});
&foreign_call($cron->{'module'}, $cron->{'func'}, @args);
