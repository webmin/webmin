#!/usr/local/bin/perl
# Enable the Minecraft server at boot, or not

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%text, %in, %config, $module_config_directory);
&ReadParse();

&foreign_require("init");
my $starting = &init::action_status($config{'init_name'});
if ($starting != 2 && $in{'boot'}) {
	# Enable at boot
	my $pidfile = &get_pid_file();
	my $startcmd = &get_start_command("& echo \$! >$pidfile");
	my $fifo = &get_input_fifo();
	my $stopcmd = "echo /stop > $fifo ; kill `lsof -t $fifo`";
	if ($config{'unix_user'} ne 'root') {
		$stopcmd = &command_as_user($config{'unix_user'}, 0, $stopcmd);
		}

	# Run via wrapper scripts, as some boot systems don't like a lot of
	# shell meta-chars
	my $startscript = "$module_config_directory/start.sh";
	my $stopscript = "$module_config_directory/stop.sh";
	my $startfh = "START";
	&open_tempfile($startfh, ">$startscript");
	&print_tempfile($startfh, "#!/bin/sh\n");
	&print_tempfile($startfh, $startcmd,"\n");
	&close_tempfile($startfh);
	&set_ownership_permissions(undef, undef, 0755, $startscript);
	my $stopfh = "STOP";
	&open_tempfile($stopfh, ">$stopscript");
	&print_tempfile($stopfh, "#!/bin/sh\n");
	&print_tempfile($stopfh, $stopcmd,"\n");
	&close_tempfile($stopfh);
	&set_ownership_permissions(undef, undef, 0755, $stopscript);

	&init::enable_at_boot($config{'init_name'},
		"Start Minecraft server",
		$startscript,
		$stopscript,
		undef,
		{ 'fork' => 1 },
		);
	&webmin_log("atboot");
	}
elsif ($starting == 2 && !$in{'boot'}) {
	# Disable at boot
	&init::disable_at_boot($config{'init_name'});
	&webmin_log("delboot");
	}

&redirect("");

