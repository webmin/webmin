#!/usr/local/bin/perl
# save_config.cgi
# Update or create the config section

require './ipsec-lib.pl';
&ReadParse();
&error_setup($text{'config_err'});
@conf = &get_config();
($config) = grep { $_->{'name'} eq 'config' } @conf;
if (!$config) {
	$config = { 'name' => 'config',
		    'value' => 'setup',
		    'values' => { } };
	}

# Validate and store inputs
if ($in{'ifaces_mode'} == 0) {
	delete($config->{'values'}->{'interfaces'});
	}
elsif ($in{'ifaces_mode'} == 1) {
	$config->{'values'}->{'interfaces'} = '%none';
	}
elsif ($in{'ifaces_mode'} == 2) {
	$config->{'values'}->{'interfaces'} = '%defaultroute';
	}
else {
	for($n=0; defined($ri = $in{"ri_$n"}); $n++) {
		next if (!$ri);
		$ii = $in{"ii_$n"};
		$done{$ri}++ && &error(&text('config_eri', $ri));
		push(@ifaces, "$ii=$ri");
		}
	@ifaces || &error($text{'config_enone'});
	$config->{'values'}->{'interfaces'} = join(" ", @ifaces);
	}

if ($in{'syslog_def'}) {
	delete($config->{'values'}->{'syslog'});
	}
else {
	$config->{'values'}->{'syslog'} = $in{'fac'}.".".$in{'pri'};
	}

if ($in{'fwd'} eq 'yes' || $config->{'values'}->{'forwardcontrol'}) {
	$config->{'values'}->{'forwardcontrol'} = $in{'fwd'};
	}
else {
	delete($config->{'values'}->{'forwardcontrol'});
	}

if ($in{'fwd'} eq 'yes' || $config->{'values'}->{'forwardcontrol'}) {
	$config->{'values'}->{'forwardcontrol'} = $in{'fwd'};
	}
else {
	delete($config->{'values'}->{'forwardcontrol'});
	}

if ($in{'nat'} eq 'yes' || $config->{'values'}->{'nat_traversal'}) {
	$config->{'values'}->{'nat_traversal'} = $in{'nat'};
	}
else {
	delete($config->{'values'}->{'nat_traversal'});
	}

# Create or update the section
$file = $config->{'file'} || $config{'file'};
&lock_file($file);
if ($config->{'file'}) {
	&modify_conn($config);
	}
else {
	&create_conn($config);
	}
&unlock_file($file);
&webmin_log("config");
&redirect("");

