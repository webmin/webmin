#!/usr/local/bin/perl
# Save global Kea DHCP options.

use strict;
use warnings;
require './kea-dhcp-lib.pl';    ## no critic
&ReadParse();
our (%in, %text);
&error_setup($text{'eacl_aviol'});

my $ver = $in{'version'} == 6 ? 6 : 4;
my %access = &get_module_acl();
&error("$text{'eacl_np'} $text{'eacl_pedit'.$ver}")
	if (!$access{'edit'.$ver});
my ($c, $root, $data, $err) = &kea_read_dhcp_config($ver);
&error($err) if ($err);

&error_setup($text{'save_failsave'});

# Rebuild top-level daemon connection settings from the form while preserving
# unrelated Kea keys that this UI does not manage.
$root->{'interfaces-config'} = { }
	if (ref($root->{'interfaces-config'}) ne 'HASH');
my @ifaces = grep { $_ ne '' } split(/[,\s]+/, $in{'interfaces'} || "");
$root->{'interfaces-config'}->{'interfaces'} = \@ifaces;
if ($ver == 4 && $in{'dhcp-socket-type'} =~ /^(raw|udp)$/) {
	$root->{'interfaces-config'}->{'dhcp-socket-type'} = $in{'dhcp-socket-type'};
	}
else {
	delete($root->{'interfaces-config'}->{'dhcp-socket-type'});
	}

# Lease storage is a daemon-level backend choice. Only common fields are shown,
# so any unexposed backend fields already in the config stay attached to the
# same hash.
$root->{'lease-database'} = { }
	if (ref($root->{'lease-database'}) ne 'HASH');
&kea_set_optional($root->{'lease-database'}, 'type', $in{'lease_type'});
&kea_set_optional_integer($root->{'lease-database'}, 'lfc-interval',
			  $in{'lease_lfc_interval'});
foreach my $k ('name', 'host', 'user') {
	&kea_set_optional($root->{'lease-database'}, $k, $in{'lease_'.$k});
	}
&kea_set_optional($root->{'lease-database'}, 'password', $in{'lease_password'})
	if (&kea_trim_form_value($in{'lease_password'}) ne '');
&kea_set_optional_integer($root->{'lease-database'}, 'port', $in{'lease_port'});
delete($root->{'lease-database'})
	if (!grep { defined($_) } values(%{$root->{'lease-database'}}));

# The UI edits Kea's classic singular control-socket block. Newer or unusual
# management API definitions remain in the parsed config unless edited manually.
$root->{'control-socket'} = { }
	if (ref($root->{'control-socket'}) ne 'HASH');
&kea_set_optional($root->{'control-socket'}, 'socket-type',
		  $in{'control_socket_type'});
&kea_set_optional($root->{'control-socket'}, 'socket-name',
		  $in{'control_socket_name'});
delete($root->{'control-socket'})
	if (!grep { defined($_) } values(%{$root->{'control-socket'}}));

# Loggers are root-level daemon settings. Keep extra logger/output fields when
# possible, but let the visible row values drive the common fields.
$root->{'loggers'} = &kea_parse_logger_rows($root->{'loggers'}, "log_");
delete($root->{'loggers'}) if (!@{$root->{'loggers'}});

# DHCP-DDNS sender settings decide whether this DHCP daemon sends name-change
# requests to D2. Keep the receiver-side D2 configuration in edit_ddns.cgi.
$root->{'dhcp-ddns'} = { }
	if (ref($root->{'dhcp-ddns'}) ne 'HASH');
&kea_set_optional_bool($root->{'dhcp-ddns'}, 'enable-updates',
		       $in{'ddns_enable_updates'});
&kea_set_optional_string($root->{'dhcp-ddns'}, 'server-ip',
			 $in{'ddns_server_ip'});
&kea_set_optional_integer($root->{'dhcp-ddns'}, 'server-port',
			  $in{'ddns_server_port'});
&kea_set_optional_string($root->{'dhcp-ddns'}, 'sender-ip',
			 $in{'ddns_sender_ip'});
&kea_set_optional_integer($root->{'dhcp-ddns'}, 'sender-port',
			  $in{'ddns_sender_port'});
&kea_set_optional_integer($root->{'dhcp-ddns'}, 'max-queue-size',
			  $in{'ddns_max_queue_size'});
&kea_set_optional_string($root->{'dhcp-ddns'}, 'ncr-protocol',
			 $in{'ddns_ncr_protocol'});
&kea_set_optional_string($root->{'dhcp-ddns'}, 'ncr-format',
			 $in{'ddns_ncr_format'});
delete($root->{'dhcp-ddns'})
	if (!grep { defined($_) } values(%{$root->{'dhcp-ddns'}}));

# These DDNS behavior flags live on the DHCP daemon root and are inherited by
# more specific scopes unless shared networks or subnets override them.
foreach my $k ('ddns-send-updates', 'ddns-override-no-update',
	       'ddns-override-client-update', 'ddns-update-on-renew') {
	&kea_set_optional_bool($root, $k, $in{$k});
	}
foreach my $k ('ddns-replace-client-name', 'ddns-generated-prefix',
	       'ddns-qualifying-suffix', 'ddns-conflict-resolution-mode',
	       'hostname-char-set', 'hostname-char-replacement') {
	&kea_set_optional_string($root, $k, $in{$k});
	}

# Keep known options in named fields and merge any additional option-data rows
# back into the original option array.
my $opts = ref($root->{'option-data'}) eq 'ARRAY' ?
	[ @{$root->{'option-data'}} ] : [ ];
&kea_parse_common_option_rows($opts, $ver, "common_");
&kea_parse_advanced_option_rows($opts, $ver, "adv_");
$opts = &kea_parse_other_option_rows($opts, $ver, "opt_");
$root->{'option-data'} = $opts;

# Lease timers and boot fields are native Kea root keys, not DHCP option-data.
# Keep this separate so option parsing cannot accidentally create timer options.
foreach my $k ('renew-timer', 'rebind-timer', 'valid-lifetime',
	       'min-valid-lifetime', 'max-valid-lifetime') {
	&kea_set_optional_integer($root, $k, $in{$k});
	}
&kea_set_optional_integer($root, 'preferred-lifetime', $in{'preferred-lifetime'})
	if ($ver == 6);
&kea_validate_lifetimes($root);
if ($ver == 4) {
	&kea_set_optional_bool($root, 'authoritative', $in{'authoritative'});
	}
else {
	delete($root->{'authoritative'});
	}
if ($ver == 4) {
	foreach my $k ('next-server', 'server-hostname', 'boot-file-name') {
		&kea_set_optional($root, $k, $in{$k});
		}
	}

# Save the full parsed config object so unmanaged sections like hooks/classes
# are retained.
my $saveerr = &kea_save_component_config($c, $data);
&error($saveerr) if ($saveerr);
&webmin_log("modify", "global-options", "dhcp$ver", \%in);
&redirect("index.cgi?mode=dhcp$ver");
