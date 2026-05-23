#!/usr/local/bin/perl
# Edit global Kea DHCP options for DHCPv4 or DHCPv6.

use strict;
use warnings;
require './kea-dhcp-lib.pl';
&ReadParse();
our (%in, %text);
&error_setup($text{'eacl_aviol'});

my $ver = $in{'version'} == 6 ? 6 : 4;
&kea_assert_acl('edit'.$ver);
my ($c, $root, $data, $err) = &kea_read_dhcp_config($ver);
&error($err) if ($err);

# Render one global settings form for either Dhcp4 or Dhcp6. Each tab writes
# back to the same JSON root object, so the save handler can update all fields
# in one pass without losing hidden tab values.
&ui_print_header(undef, &text('options_title', $ver), "", undef, 1, 1);
print &kea_comment_loss_warning($c);
print &ui_alert_box($text{'dhcp6_ra_warn'}, "warn", undef, undef, "")
	if ($ver == 6);
print &ui_form_start("save_options.cgi", "post");
print &ui_hidden("version", $ver);

my @tabs = (
	[ 'interfaces', $text{'tab_interfaces'} ],
	[ 'storage', $text{'tab_storage'} ],
	[ 'logging', $text{'tab_logging'} ],
	[ 'ddns_sender', $text{'tab_ddns_sender'} ],
	[ 'timers', $text{'tab_timers'} ],
	[ 'options', $text{'tab_options'} ],
	[ 'advanced', $text{'tab_advanced'} ],
	);
print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || "interfaces", 1);

# Interfaces decide whether Kea listens at all. The DHCPv4 socket mode is kept
# beside the interface list because it only affects packet capture on DHCPv4.
print &ui_tabs_start_tab("mode", "interfaces");
print &ui_div($text{'interfaces_desc'});
my $ifconf = ref($root->{'interfaces-config'}) eq 'HASH' ?
	$root->{'interfaces-config'} : { };
my $ifaces = ref($ifconf->{'interfaces'}) eq 'ARRAY' ?
	join(" ", @{$ifconf->{'interfaces'}}) : "";
print &ui_table_start($text{'interfaces_title'}, "width=100%", 4);
print &ui_table_row(&kea_field_hlink('interfaces', $text{'interfaces_list'}),
	&ui_textbox("interfaces", $ifaces, 60));
if ($ver == 4) {
	print &ui_table_row(&kea_field_hlink('dhcp-socket-type',
					     $text{'interfaces_socket'}),
		&ui_select("dhcp-socket-type", $ifconf->{'dhcp-socket-type'} || "",
			[ [ "", $text{'socket_default'} ],
			  [ "raw", $text{'socket_raw'} ],
			  [ "udp", $text{'socket_udp'} ] ]));
	}
print &ui_table_end();
print &ui_tabs_end_tab("mode", "interfaces");

# Storage and control sockets are global daemon settings, not subnet settings.
print &ui_tabs_start_tab("mode", "storage");
print &ui_div($text{'storage_desc'});
my $lease = ref($root->{'lease-database'}) eq 'HASH' ?
	$root->{'lease-database'} : { };
print &ui_table_start($text{'lease_database'}, "width=100%", 4);
print &ui_table_row(&kea_field_hlink('lease-database-type', $text{'lease_type'}),
	&ui_textbox("lease_type", $lease->{'type'} || "", 20));
print &ui_table_row(&kea_field_hlink('lfc-interval',
				     $text{'lease_lfc_interval'}),
	&ui_textbox("lease_lfc_interval", $lease->{'lfc-interval'} || "", 12));
print &ui_table_row(&kea_field_hlink('lease-database-name',
				     $text{'lease_name'}),
	&ui_textbox("lease_name", $lease->{'name'} || "", 30));
print &ui_table_row(&kea_field_hlink('lease-database-host',
				     $text{'lease_host'}),
	&ui_textbox("lease_host", $lease->{'host'} || "", 30));
print &ui_table_row(&kea_field_hlink('lease-database-port',
				     $text{'lease_port'}),
	&ui_textbox("lease_port", $lease->{'port'} || "", 8));
print &ui_table_row(&kea_field_hlink('lease-database-user',
				     $text{'lease_user'}),
	&ui_textbox("lease_user", $lease->{'user'} || "", 24));
my $password_note = $lease->{'password'} ?
	" ".&ui_tag('small', $text{'secret_keep_blank'}, {
		'style' => 'color:var(--text-color-light, #777)' }) : "";
print &ui_table_row(&kea_field_hlink('lease-database-password',
				     $text{'lease_password'}),
	&ui_password("lease_password", "", 24).$password_note);
print &ui_table_end();

my $socket = ref($root->{'control-socket'}) eq 'HASH' ?
	$root->{'control-socket'} : { };
print &ui_table_start($text{'control_socket'}, "width=100%", 4);
print &ui_table_row(&kea_field_hlink('control-socket-type',
				     $text{'control_socket_type'}),
	&ui_select("control_socket_type", $socket->{'socket-type'} || "",
		[ [ "", $text{'socket_default'} ],
		  [ "unix", "Unix" ] ]));
print &ui_table_row(&kea_field_hlink('control-socket-name',
				     $text{'control_socket_name'}),
	&ui_textbox("control_socket_name", $socket->{'socket-name'} || "", 50));
print &ui_table_end();
print &ui_tabs_end_tab("mode", "storage");

# Logger settings live at the daemon root, beside lease database and timers.
print &ui_tabs_start_tab("mode", "logging");
print &ui_div($text{'logging_desc'});
print &ui_subheading($text{'logging_loggers'});
&kea_logger_rows($root->{'loggers'}, "log_");
print &ui_tabs_end_tab("mode", "logging");

# DHCP-DDNS sender settings control whether this daemon submits name-change
# requests to the standalone D2 daemon. They are distinct from D2's own
# listener/zones/keys settings.
print &ui_tabs_start_tab("mode", "ddns_sender");
print &ui_div(&text('ddns_sender_settings_desc', $ver));
my $ddns = ref($root->{'dhcp-ddns'}) eq 'HASH' ?
	$root->{'dhcp-ddns'} : { };
my $bool_opts = [
	[ "", $text{'inherit_default'} ],
	[ "true", $text{'yes'} ],
	[ "false", $text{'no'} ],
	];
print &ui_table_start($text{'ddns_sender_connectivity'}, "width=100%", 4);
print &ui_table_row(&kea_field_hlink('ddns-enable-updates',
				     $text{'ddns_enable_updates'}),
	&ui_select("ddns_enable_updates",
		&kea_bool_value($ddns->{'enable-updates'}), $bool_opts));
print &ui_table_row(&kea_field_hlink('ddns-server-ip',
				     $text{'ddns_server_ip'}),
	&ui_textbox("ddns_server_ip", $ddns->{'server-ip'} || "", 24));
print &ui_table_row(&kea_field_hlink('ddns-server-port',
				     $text{'ddns_server_port'}),
	&ui_textbox("ddns_server_port",
		    defined($ddns->{'server-port'}) ? $ddns->{'server-port'} : "",
		    8));
print &ui_table_row(&kea_field_hlink('ddns-sender-ip',
				     $text{'ddns_sender_ip'}),
	&ui_textbox("ddns_sender_ip", $ddns->{'sender-ip'} || "", 24));
print &ui_table_row(&kea_field_hlink('ddns-sender-port',
				     $text{'ddns_sender_port'}),
	&ui_textbox("ddns_sender_port",
		    defined($ddns->{'sender-port'}) ? $ddns->{'sender-port'} : "",
		    8));
print &ui_table_row(&kea_field_hlink('ddns-max-queue-size',
				     $text{'ddns_max_queue_size'}),
	&ui_textbox("ddns_max_queue_size",
		    defined($ddns->{'max-queue-size'}) ?
			$ddns->{'max-queue-size'} : "", 10));
print &ui_table_row(&kea_field_hlink('ncr-protocol',
				     $text{'ddns_ncr_protocol'}),
	&ui_select("ddns_ncr_protocol", $ddns->{'ncr-protocol'} || "",
		&kea_select_options($ddns->{'ncr-protocol'},
				    $text{'socket_default'}, 'UDP')));
print &ui_table_row(&kea_field_hlink('ncr-format',
				     $text{'ddns_ncr_format'}),
	&ui_select("ddns_ncr_format", $ddns->{'ncr-format'} || "",
		&kea_select_options($ddns->{'ncr-format'},
				    $text{'socket_default'}, 'JSON')));
print &ui_table_end();

print &ui_table_start($text{'ddns_sender_behavior'}, "width=100%", 4);
my %ddns_bool_labels = (
	'ddns-send-updates' => $text{'ddns_send_updates'},
	'ddns-override-no-update' => $text{'ddns_override_no_update'},
	'ddns-override-client-update' => $text{'ddns_override_client_update'},
	'ddns-update-on-renew' => $text{'ddns_update_on_renew'},
	);
foreach my $k ('ddns-send-updates', 'ddns-override-no-update',
	       'ddns-override-client-update', 'ddns-update-on-renew') {
	print &ui_table_row(&kea_field_hlink($k, $ddns_bool_labels{$k}),
		&ui_select($k, &kea_bool_value($root->{$k}), $bool_opts));
	}
print &ui_table_row(&kea_field_hlink('ddns-replace-client-name',
				     $text{'ddns_replace_client_name'}),
	&ui_select("ddns-replace-client-name",
		$root->{'ddns-replace-client-name'} || "",
		&kea_select_options($root->{'ddns-replace-client-name'},
				    $text{'socket_default'},
				    'never', 'when-present',
				    'when-not-present', 'always')));
my %ddns_text_labels = (
	'ddns-generated-prefix' => $text{'ddns_generated_prefix'},
	'ddns-qualifying-suffix' => $text{'ddns_qualifying_suffix'},
	'ddns-conflict-resolution-mode' => $text{'ddns_conflict_resolution_mode'},
	'hostname-char-set' => $text{'hostname_char_set'},
	'hostname-char-replacement' => $text{'hostname_char_replacement'},
	);
foreach my $k ('ddns-generated-prefix', 'ddns-qualifying-suffix',
	       'ddns-conflict-resolution-mode', 'hostname-char-set',
	       'hostname-char-replacement') {
	print &ui_table_row(&kea_field_hlink($k, $ddns_text_labels{$k}),
		&ui_textbox($k, defined($root->{$k}) ? $root->{$k} : "", 32));
	}
print &ui_table_end();
print &ui_tabs_end_tab("mode", "ddns_sender");

# Timer defaults apply only when shared networks or subnets do not override.
print &ui_tabs_start_tab("mode", "timers");
print &ui_div($text{'timers_desc'});
print &ui_table_start($text{'options_timers'}, "width=100%", 4);
foreach my $k ('renew-timer', 'rebind-timer', 'valid-lifetime',
	       'min-valid-lifetime', 'max-valid-lifetime') {
	print &ui_table_row(&kea_field_hlink($k),
		&ui_textbox($k, defined($root->{$k}) ? $root->{$k} : "", 12));
	}
print &ui_table_row(&kea_field_hlink('preferred-lifetime'),
	&ui_textbox("preferred-lifetime",
		    defined($root->{'preferred-lifetime'}) ? $root->{'preferred-lifetime'} : "", 12))
	if ($ver == 6);
print &ui_table_end();
print &ui_tabs_end_tab("mode", "timers");

# Common options get named fields; everything else remains editable in the
# additional option-data table below them.
print &ui_tabs_start_tab("mode", "options");
print &ui_div($text{'options_desc'});
&kea_common_option_rows($root->{'option-data'}, $ver, "common_");
&kea_option_data_section($root->{'option-data'}, "opt_", $ver, 1);
print &ui_tabs_end_tab("mode", "options");

# Advanced fields are valid Kea globals but are easy to misuse, so keep them
# away from the everyday options page.
print &ui_tabs_start_tab("mode", "advanced");
print &ui_div(&text('global_advanced_desc', $ver));
print &ui_table_start($text{'global_advanced'}, "width=100%", 4);
if ($ver == 4) {
	print &ui_table_row(&kea_field_hlink('authoritative'),
		&ui_select("authoritative", &kea_bool_value($root->{'authoritative'}),
			[ [ "", $text{'inherit_default'} ],
			  [ "true", $text{'yes'} ],
			  [ "false", $text{'no'} ] ]));
	}
&kea_advanced_option_rows($root->{'option-data'}, $ver, "adv_");
if ($ver == 4) {
	foreach my $k ('next-server', 'server-hostname', 'boot-file-name') {
		print &ui_table_row(&kea_field_hlink($k),
			&ui_textbox($k, defined($root->{$k}) ? $root->{$k} : "", 40));
		}
	}
print &ui_table_end();
print &ui_tabs_end_tab("mode", "advanced");
print &ui_tabs_end();

print &ui_form_end([ [ "save", $text{'save'} ] ]);
&ui_print_footer("index.cgi?mode=dhcp$ver", $text{'index_return'});
