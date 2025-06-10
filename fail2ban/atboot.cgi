#!/usr/local/bin/perl
# Enable the Fail2ban server at boot, or not

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './fail2ban-lib.pl';
our (%text, %in, %config, $module_config_directory);
&ReadParse();

&foreign_require("init");
my $log;
foreach my $init (split(/\s+/, $config{'init_script'})) {
	my $starting = &init::action_status($init);
	if ($starting != 2 && $in{'boot'}) {
		# Enable at boot
		my $startscript = &has_command($config{'client_cmd'})." -x start";
		my $stopscript = &has_command($config{'client_cmd'})." stop";
		&init::enable_at_boot($config{'init_script'},
			"Start Fail2Ban server",
			$startscript,
			$stopscript,
			undef,
			{ 'fork' => 1 },
			);
		$log = "atboot";
		}
	elsif ($starting == 2 && !$in{'boot'}) {
		# Disable at boot
		&init::disable_at_boot($config{'init_script'});
		$log = "delboot";
		}
	}
&webmin_log($log) if ($log);

&redirect("");

