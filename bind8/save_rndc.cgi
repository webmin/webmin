#!/usr/local/bin/perl
# Actually setup rndc
use strict;
use warnings;
our (%access, %text, %config);

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'rndc_ecannot'});
&error_setup($text{'rndc_err'});
my $cfile = &make_chroot($config{'named_conf'});

# Generate the RNDC config
my ($out, $err);
&execute_command($config{'rndcconf_cmd'}, undef, \$out, \$err);
if ($?) {
	&error("<pre>$err</pre>");
	}
my $CONF;
&open_lock_tempfile($CONF, ">$config{'rndc_conf'}");
&print_tempfile($CONF, $out);
&close_tempfile($CONF);
&set_ownership_permissions(0, 0, 0600, $config{'rndc_conf'});
my $rconf = [ &read_config_file($config{'rndc_conf'}) ];

# Get the new key
my $rkey = &find("key", $rconf);
$rkey || &error($text{'rndc_ekey'});
my $secret = &find_value("secret", $rkey->{'members'});
$secret || &error($text{'rndc_esecret'});
my $options = &find("options", $rconf);
my $port;
if ($options) {
	$port = &find_value("default-port", $options->{'members'});
	}
$port ||= 953;

# Add the key to named.conf
&lock_file($cfile);
my $parent = &get_config_parent();
my $conf = &get_config();
my @keys = &find("key", $conf);
my ($key) = grep { $_->{'values'}->[0] eq "rndc-key" } @keys;
if (!$key) {
	# Need to create key
	$key = { 'name' => 'key',
		 'type' => 1,
		 'values' => [ "rndc-key" ],
		 'members' => [ ] };
	push(@keys, $key);
	}
&save_directive($key, "algorithm", [ { 'name' => 'algorithm',
			'values' => [ "hmac-md5" ] } ], 1, 1);
&save_directive($key, "secret", [ { 'name' => 'secret',
			'values' => [ $secret ] } ], 1, 1);
&save_directive($parent, 'key', \@keys, 0);

# Make sure there is a control for the inet port
my $controls = &find("controls", $conf);
if (!$controls) {
	# Need to add controls section
	$controls = { 'name' => 'controls', 'type' => 1 };
	&save_directive($parent, 'controls', [ $controls ]);
	}
my $inet = &find("inet", $controls->{'members'});
if (!$inet) {
	# Need to add inet entry
	$inet = { 'name' => 'inet',
		  'type' => 2,
		  'values' => [ "127.0.0.1", "port", $port ],
		  'members' => { 'allow' => [
				  { 'name' => "127.0.0.1" } ],
				'keys' => [
				  { 'name' => "rndc-key" } ]
			      }
		};
	}
else {
	# Just make sure it is valid
	my %keys = map { $_->{'name'}, 1 } @{$inet->{'members'}->{'keys'}};
	if (!$keys{'rndc-key'}) {
		push(@{$inet->{'members'}->{'keys'}},
		     { 'name' => "rndc-key" });
		}
	}
&save_directive($controls, 'inet', [ $inet ], 1);

&flush_file_lines();

# MacOS specific fix - remove include for /etc/rndc.key , which we don't need
my $lref = &read_file_lines($cfile);
for(my $i=0; $i<@$lref; $i++) {
	if ($lref->[$i] =~ /^include\s+"\/etc\/rndc.key"/i) {
		splice(@$lref, $i, 1);
		last;
		}
	}
&flush_file_lines($cfile);

&unlock_file($cfile);
&restart_bind();
&webmin_log("rndc");
&redirect("");

