#!/usr/local/bin/perl
# Actually setup rndc

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'rndc_ecannot'});
&error_setup($text{'rndc_err'});
$cfile = &make_chroot($config{'named_conf'});

# Generate the RNDC config
&execute_command($config{'rndcconf_cmd'}, undef, \$out, \$err);
if ($?) {
	&error("<pre>$err</pre>");
	}
&open_lock_tempfile(CONF, ">$config{'rndc_conf'}");
&print_tempfile(CONF, $out);
&close_tempfile(CONF);
&set_ownership_permissions(0, 0, 0600, $config{'rndc_conf'});
$rconf = [ &read_config_file($config{'rndc_conf'}) ];

# Get the new key
$rkey = &find("key", $rconf);
$rkey || &error($text{'rndc_ekey'});
$secret = &find_value("secret", $rkey->{'members'});
$secret || &error($text{'rndc_esecret'});
$options = &find("options", $rconf);
if ($options) {
	$port = &find_value("default-port", $options->{'members'});
	}
$port ||= 953;

# Add the key to named.conf
&lock_file($cfile);
$parent = &get_config_parent();
$conf = &get_config();
@keys = &find("key", $conf);
($key) = grep { $_->{'values'}->[0] eq "rndc-key" } @keys;
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
$controls = &find("controls", $conf);
if (!$controls) {
	# Need to add controls section
	$controls = { 'name' => 'controls', 'type' => 1 };
	&save_directive($parent, 'controls', [ $controls ]);
	}
$inet = &find("inet", $controls->{'members'});
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
	%keys = map { $_->{'name'}, 1 } @{$inet->{'members'}->{'keys'}};
	if (!$keys{'rndc-key'}) {
		push(@{$inet->{'members'}->{'keys'}},
		     { 'name' => "rndc-key" });
		}
	}
&save_directive($controls, 'inet', [ $inet ], 1);

&flush_file_lines();

# MacOS specific fix - remove include for /etc/rndc.key , which we don't need
$lref = &read_file_lines($cfile);
for(my $i=0; $i<@$lref; $i++) {
	if ($lref->[$i] =~ /^include\s+"/etc/rndc.key"/i) {
		splice(@$lref, $i, 1);
		last;
		}
	}
&flush_file_lines($cfile);

&unlock_file($cfile);
&restart_bind();
&webmin_log("rndc");
&redirect("");

