#!/usr/local/bin/perl
# save_options.cgi
# Save voicemail server options

require './vgetty-lib.pl';
&ReadParse();
&error_setup($text{'options_err'});
@conf = &get_config();

# Validate inputs
$in{'rings'} =~ /^\d+$/ || &error($text{'options_erings'});
$in{'rings'} >= 2 || &error($text{'options_erings2'});
$ans = &parse_answer_mode("ans");
$in{'maxlen'} =~ /^\d+$/ || &error($text{'options_emaxlen'});
$in{'minlen'} =~ /^\d+$/ || &error($text{'options_eminlen'});
$in{'thresh'} =~ /^\d+$/ || &error($text{'options_ethresh'});
if (!$in{'rgain_def'}) {
	$in{'rgain'} =~ /^\d+$/ || &error($text{'options_ergain'});
	$in{'rgain'} >= 0 && $in{'rgain'} <= 100 ||
		&error($text{'options_ergain2'});
	}
if (!$in{'tgain_def'}) {
	$in{'tgain'} =~ /^\d+$/ || &error($text{'options_etgain'});
	$in{'tgain'} >= 0 && $in{'tgain'} <= 100 ||
		&error($text{'options_etgain2'});
	}
defined(getpwnam($in{'owner'})) || &error($text{'options_eowner'});
defined(getgrnam($in{'group'})) || &error($text{'options_egroup'});
$in{'mode'} =~ /^0[0-7]{3}$/ || &error($text{'options_emode'});
if ($in{'prog_mode'} == 1) {
	$in{'email'} =~ /^\S+$/ || &error($text{'options_eemail'});
	}
elsif ($in{'prog_mode'} == 2) {
	$in{'prog'} =~ /^(\S+)/ && &has_command($1) ||
		&error($text{'options_eprog'});
	}

# Write to config files
&lock_file($config{'vgetty_config'});
$rings = &find_value("rings", \@conf);
if ($in{'rings_port'}) {
	local $tf = $rings =~ /^\// ? $rings : "/etc/rings";
	&open_lock_tempfile(TF, ">$tf");
	&print_tempfile(TF, $in{'rings'},"\n");
	&close_tempfile(TF);
	&save_directive(\@conf, "rings", $tf);
	}
else {
	if ($rings =~ /^\//) {
		&lock_file($rings);
		unlink($rings);
		&unlock_file($rings);
		}
	&save_directive(\@conf, "rings", $in{'rings'});
	}
$ans = &find_value("answer_mode", \@conf);
$mode = &parse_answer_mode("ans");
if ($in{'ans_port'}) {
	local $tf = $ans =~ /^\// ? $ans : "/etc/answer";
	&open_lock_tempfile(TF, ">$tf");
	&print_tempfile(TF, "$mode\n");
	&close_tempfile(TF);
	&save_directive(\@conf, "answer_mode", $tf);
	}
else {
	if ($ans =~ /^\//) {
		&lock_file($ans);
		unlink($ans)
		&unlock_file($ans);
		}
	&save_directive(\@conf, "answer_mode", $mode);
	}

&save_directive(\@conf, "rec_max_len", $in{'maxlen'});
&save_directive(\@conf, "rec_min_len", $in{'minlen'});
&save_directive(\@conf, "rec_remove_silence", $in{'silence'} ? "true" :"false");
&save_directive(\@conf, "rec_silence_threshold", $in{'thresh'});
&save_directive(\@conf, "receive_gain", $in{'rgain_def'} ? -1 : $in{'rgain'});
&save_directive(\@conf, "transmit_gain", $in{'tgain_def'} ? -1 : $in{'tgain'});
&save_directive(\@conf, "rec_always_keep", $in{'keep'} ? "true" : "false");
&save_directive(\@conf, "do_message_light", $in{'light'} ? "true" : "false");
&save_directive(\@conf, "phone_owner", $in{'owner'});
&save_directive(\@conf, "phone_group", $in{'group'});
&save_directive(\@conf, "phone_mode", $in{'mode'});
if ($in{'prog_mode'} == 1) {
	# Need to create the email wrapper script
	local $script = "$module_config_directory/email.pl";
	$perl_path = &get_perl_path();
	&lock_file($script);
	&open_tempfile(SCRIPT, ">$script");
	&print_tempfile(SCRIPT, <<EOF
#!/bin/sh -- # -*- perl -*-
eval 'exec $perl_path -S \$0 \${1+"\$\@"}'
        if \$running_under_some_shell;
open(CONF, "$config_directory/miniserv.conf");
while(<CONF>) {
	\$root = \$1 if (/^root=(.*)/);
	}
close(CONF);
\$ENV{'WEBMIN_CONFIG'} = "$ENV{'WEBMIN_CONFIG'}";
\$ENV{'WEBMIN_VAR'} = "$ENV{'WEBMIN_VAR'}";
chdir("\$root/$module_name");
exec("\$root/$module_name/email.pl", \$ARGV[0]);
EOF
	);
	&close_tempfile(CMD);
	chmod(0755, $script);
	&unlock_file($script);
	&save_directive(\@conf, "message_program", $script);
	$config{'email_to'} = $in{'email'};
	&save_module_config();
	}
elsif ($in{'prog_mode'} == 2) {
	&save_directive(\@conf, "message_program", $in{'prog'});
	}
else {
	&save_directive(\@conf, "message_program", "");
	}
&flush_file_lines();
&unlock_file($config{'vgetty_config'});
&webmin_log("options");
&redirect("");

