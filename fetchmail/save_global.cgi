#!/usr/local/bin/perl
# save_global.cgi
# Save global options

require './fetchmail-lib.pl';
&ReadParse();
&error_setup($text{'global_err'});

if ($config{'config_file'}) {
	$file = $config{'config_file'};
	}
else {
	&can_edit_user($in{'user'}) || &error($text{'poll_ecannot'});
	@uinfo = getpwnam($in{'user'});
	$file = "$uinfo[7]/.fetchmailrc";
	}

&lock_file($file);
@conf = &parse_config_file($file);
foreach $c (@conf) {
	$poll = $c if ($c->{'defaults'});
	}
$found++ if ($poll);

# Validate inputs
$in{'port_def'} || $in{'port'} =~ /^\d+$/ ||
	&error($text{'poll_eport'});
if (!$in{'interface_def'}) {
	$in{'interface'} =~ /^\S+$/ || &error($text{'poll_einterface'});
	&check_ipaddress($in{'interface_net'}) || &error($text{'poll_enet'});
	&check_ipaddress($in{'interface_mask'}) || !$in{'interface_mask'} ||
		&error($text{'poll_emask'});
	}

# Create the default structure
$poll->{'defaults'} = 1;
$poll->{'proto'} = $in{'proto'};
$poll->{'port'} = $in{'port_def'} ? undef : $in{'port'};
if ($in{'interface_def'}) {
	delete($poll->{'interface'});
	}
else {
	local @interface = ( $in{'interface'}, $in{'interface_net'} );
	push(@interface, $in{'interface_mask'}) if ($in{'interface_mask'});
	$poll->{'interface'} = join("/", @interface);
	}

if ($found) {
	&modify_poll($poll, $file);
	}
else {
	&create_poll($poll, $file);
	if ($in{'user'} && $< == 0) {
		&system_logged("chown $in{'user'} $file");
		}
	&system_logged("chmod 700 $file");
	}
&unlock_file($file);
&webmin_log("global", undef, $config{'config_file'} ? $file : $in{'user'},
	    \%in);
&redirect("");

