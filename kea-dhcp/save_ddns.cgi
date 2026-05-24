#!/usr/local/bin/perl
# Save settings for the Kea DHCP-DDNS daemon.

use strict;
use warnings;
require './kea-dhcp-lib.pl';    ## no critic
&ReadParse();
our (%in, %text);
&error_setup($text{'eacl_aviol'});
&kea_assert_acl('editddns');

my $c = &kea_component('ddns');
my ($root, $err, $data) = &kea_read_component_config($c);
&error($err) if ($err);

&error_setup($text{'save_failsave'});

# Listener settings control where D2 receives DHCP name-change requests.
&kea_set_optional_string($root, 'ip-address', $in{'ip_address'})
	if (exists($in{'ip_address'}));
&kea_set_optional_integer($root, 'port', $in{'port'})
	if (exists($in{'port'}));
&kea_set_optional_integer($root, 'dns-server-timeout',
			  $in{'dns_server_timeout'})
	if (exists($in{'dns_server_timeout'}));
&kea_set_optional_string($root, 'ncr-protocol', $in{'ncr_protocol'})
	if (exists($in{'ncr_protocol'}));
&kea_set_optional_string($root, 'ncr-format', $in{'ncr_format'})
	if (exists($in{'ncr_format'}));

# Keep the local control socket separate from DNS update transport settings.
if (exists($in{'control_socket_type'}) || exists($in{'control_socket_name'})) {
	$root->{'control-socket'} = { }
		if (ref($root->{'control-socket'}) ne 'HASH');
	&kea_set_optional_string($root->{'control-socket'}, 'socket-type',
				 $in{'control_socket_type'})
		if (exists($in{'control_socket_type'}));
	&kea_set_optional_string($root->{'control-socket'}, 'socket-name',
				 $in{'control_socket_name'})
		if (exists($in{'control_socket_name'}));
	delete($root->{'control-socket'})
		if (!grep { defined($_) } values(%{$root->{'control-socket'}}));
	}

# TSIG keys are parsed before domains so key-name references can be validated
# against the same save request.
if (&kea_form_has_prefix("key_")) {
	$root->{'tsig-keys'} = &kea_parse_tsig_key_rows($root->{'tsig-keys'}, "key_");
	}

# Forward and reverse zones share the same D2 domain object shape.
foreach my $pair ([ 'forward-ddns', 'fwd_' ], [ 'reverse-ddns', 'rev_' ]) {
	my ($section, $prefix) = @$pair;
	next if (!&kea_form_has_prefix($prefix));
	$root->{$section} = { } if (ref($root->{$section}) ne 'HASH');
	my $domains = &kea_parse_ddns_domain_rows(
		&kea_ddns_domains($root, $section), $prefix,
		$root->{'tsig-keys'});
	if (@$domains) {
		$root->{$section}->{'ddns-domains'} = $domains;
		}
	else {
		delete($root->{$section}->{'ddns-domains'});
		}
	}

# Loggers are root-level D2 settings.
if (&kea_form_has_prefix("log_")) {
	$root->{'loggers'} = &kea_parse_logger_rows($root->{'loggers'}, "log_");
	delete($root->{'loggers'}) if (!@{$root->{'loggers'}});
	}

my $saveerr = &kea_save_component_config($c, $data);
&error($saveerr) if ($saveerr);
&webmin_log("modify", "ddns", undef, \%in);
&redirect("index.cgi?mode=ddns");
