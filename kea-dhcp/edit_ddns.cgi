#!/usr/local/bin/perl
# Edit settings for the Kea DHCP-DDNS daemon.

use strict;
use warnings;
require './kea-dhcp-lib.pl';    ## no critic
&ReadParse();
our (%in, %text);
&error_setup($text{'eacl_aviol'});
&kea_assert_acl('editddns');

my $c = &kea_component('ddns');
my ($root, $err) = &kea_read_component_config($c);
&error($err) if ($err);

# D2 is a separate daemon shared by DHCPv4 and DHCPv6, so keep its settings
# outside the protocol-specific global DHCP pages.
&ui_print_header(undef, $text{'ddns_title'}, "", undef, 1, 1);
print &kea_comment_loss_warning($c);
print &ui_form_start("save_ddns.cgi", "post");

my @tabs = (
	[ 'listener', $text{'tab_listener'} ],
	[ 'zones', $text{'tab_zones'} ],
	[ 'tsig', $text{'tab_tsig'} ],
	[ 'logging', $text{'tab_logging'} ],
	);
print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || "listener", 1);

# The listener receives name-change requests from DHCPv4/DHCPv6 and exposes a
# local control socket for daemon management.
print &ui_tabs_start_tab("mode", "listener");
print &ui_div($text{'ddns_listener_desc'});
print &ui_alert_box($text{'ddns_listener_warn'}, "warn", undef, undef, "")
	if (&kea_ddns_listener_non_loopback($root));
print &ui_alert_box($text{'ddns_listener_warn_loopback'}, "warn", undef, undef, "")
	if (!&kea_ddns_listener_non_loopback($root) &&
	    &kea_ddns_listener_non_default_loopback($root));
print &ui_table_start($text{'ddns_listener'}, "width=100%", 4);
print &ui_table_row(&kea_field_hlink('ddns-ip-address',
				     $text{'ddns_ip_address'}),
	&ui_textbox("ip_address", $root->{'ip-address'} || "", 24));
print &ui_table_row(&kea_field_hlink('ddns-port', $text{'ddns_port'}),
	&ui_textbox("port", defined($root->{'port'}) ? $root->{'port'} : "",
		    8));
print &ui_table_row(&kea_field_hlink('ddns-timeout', $text{'ddns_timeout'}),
	&ui_textbox("dns_server_timeout",
		    defined($root->{'dns-server-timeout'}) ?
			$root->{'dns-server-timeout'} : "", 8));
print &ui_table_row(&kea_field_hlink('ncr-protocol',
				     $text{'ddns_ncr_protocol'}),
	&ui_select("ncr_protocol", $root->{'ncr-protocol'} || "UDP",
		&kea_select_options($root->{'ncr-protocol'}, $text{'socket_default'},
				    'UDP')));
print &ui_table_row(&kea_field_hlink('ncr-format', $text{'ddns_ncr_format'}),
	&ui_select("ncr_format", $root->{'ncr-format'} || "JSON",
		&kea_select_options($root->{'ncr-format'}, $text{'socket_default'},
				    'JSON')));
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
print &ui_tabs_end_tab("mode", "listener");

# Forward and reverse DDNS domains tell D2 where to send DNS updates.
print &ui_tabs_start_tab("mode", "zones");
print &ui_div($text{'ddns_zones_desc'});
print &ui_subheading($text{'ddns_forward'});
&kea_ddns_domain_rows(&kea_ddns_domains($root, 'forward-ddns'), "fwd_");
print &ui_subheading($text{'ddns_reverse'});
&kea_ddns_domain_rows(&kea_ddns_domains($root, 'reverse-ddns'), "rev_");
print &ui_tabs_end_tab("mode", "zones");

# TSIG keys are referenced by update domains using key-name.
print &ui_tabs_start_tab("mode", "tsig");
print &ui_div($text{'ddns_tsig_desc'});
print &ui_subheading($text{'ddns_tsig_keys'});
&kea_tsig_key_rows($root->{'tsig-keys'}, "key_");
print &ui_tabs_end_tab("mode", "tsig");

# D2 uses the same Kea logger format as the DHCP daemons.
print &ui_tabs_start_tab("mode", "logging");
print &ui_div($text{'logging_desc'});
print &ui_subheading($text{'logging_loggers'});
&kea_logger_rows($root->{'loggers'}, "log_");
print &ui_tabs_end_tab("mode", "logging");
print &ui_tabs_end();

print &ui_form_end([ [ "save", $text{'save'} ] ]);
&ui_print_footer("index.cgi?mode=ddns", $text{'index_return'});
