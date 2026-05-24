#!/usr/local/bin/perl
# Display Kea DHCP service and configuration status.

use strict;
use warnings;
require './kea-dhcp-lib.pl';    ## no critic
&ReadParse();
our (%in, %text);
our $module_name;
my %access = &kea_effective_acl();
my $delete_formno;
&error_setup($text{'eacl_aviol'});
&error("$text{'eacl_np'} $text{'eacl_penter'}")
	unless &kea_can_enter_module(\%access);

# If the Kea daemons cannot be found, keep the index page focused on the
# repair path. Leftover config files are not enough to run the module safely.
if (!&kea_any_installed()) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	print &ui_p(&text('index_missing_exe',
		     "@{[&get_webprefix()]}/config.cgi?$module_name"));

	if ($access{'install'}) {
		&foreign_require("software", "software-lib.pl");
		my $lnk = &software::missing_install_link("kea", "Kea DHCP",
				"../$module_name/", $text{'index_title'});
		print &ui_p($lnk) if ($lnk);
		}

	&ui_print_footer("/", $text{'index_return'});
	exit;
	}

# The page header owns service controls, like BIND/nftables modules do.
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		 &service_action_links());

# Build the visible tab set from ACLs instead of showing links that later fail.
$delete_formno = 0;
my @tabs;
push(@tabs, [ 'dhcp4', $text{'tab_dhcp4'} ])
	if (&kea_can_view_dhcp(\%access, 4));
push(@tabs, [ 'dhcp6', $text{'tab_dhcp6'} ])
	if (&kea_can_view_dhcp(\%access, 6));
push(@tabs, [ 'ddns', $text{'tab_ddns'} ])
	if (&kea_can_view_ddns(\%access));
push(@tabs, [ 'services', $text{'tab_services'} ])
	if (&kea_can_view_services(\%access));

if (@tabs) {
	my %valid_tabs = map { $_->[0] => 1 } @tabs;
	my $mode = $in{'mode'} && $valid_tabs{$in{'mode'}} ?
		$in{'mode'} : $tabs[0]->[0];
	print &ui_tabs_start(\@tabs, "mode", $mode, 1);

	if (&kea_can_view_dhcp(\%access, 4)) {
		print &ui_tabs_start_tab("mode", "dhcp4");
		&print_dhcp_tab(4);
		print &ui_tabs_end_tab("mode", "dhcp4");
		}

	if (&kea_can_view_dhcp(\%access, 6)) {
		print &ui_tabs_start_tab("mode", "dhcp6");
		&print_dhcp_tab(6);
		print &ui_tabs_end_tab("mode", "dhcp6");
		}

	if (&kea_can_view_ddns(\%access)) {
		print &ui_tabs_start_tab("mode", "ddns");
		&print_ddns_tab();
		print &ui_tabs_end_tab("mode", "ddns");
		}

	if (&kea_can_view_services(\%access)) {
		print &ui_tabs_start_tab("mode", "services");
		print &ui_div($text{'index_services_desc'});
		&print_services_table();
		print &ui_tabs_end_tab("mode", "services");
		}

	print &ui_tabs_end();
	}

&print_action_buttons();
&ui_print_footer("/", $text{'index_return'});

# html_join_br(html, ...)
# Joins existing HTML fragments with API-generated line breaks.
sub html_join_br
{
return join(&ui_br(), grep { defined($_) && $_ ne '' } @_);
}

# html_join_escaped_lines(text, ...)
# Escapes text lines and joins them with API-generated line breaks.
sub html_join_escaped_lines
{
return &html_join_br(map { &html_escape($_) } @_);
}

# status_badge(&status)
# Renders the status cell with a compact state pill and expandable diagnostics.
sub status_badge
{
my ($status) = @_;
my $state = $status->{'state'} || 'unknown';
my $label = $state eq 'running' && $status->{'pid'} ?
		&text('status_running', $status->{'pid'}) :
	    $state eq 'running' ? $text{'status_running_nopid'} :
	    $state eq 'failed' ? $text{'status_failed'} :
	    $state eq 'skipped' ? $text{'status_skipped'} :
	    $state eq 'starting' ? $text{'status_starting'} :
	    $state eq 'stopping' ? $text{'status_stopping'} :
	    $state eq 'stopped' ? $text{'status_stopped'} :
				   $text{'status_unknown'};
my $color = $state eq 'running' ? "var(--success-color, #138a5b)" :
	    $state eq 'failed' ? "var(--danger-color, #d33)" :
	    $state eq 'skipped' ||
	    $state eq 'starting' || $state eq 'stopping' ?
		"var(--warning-color, #b7791f)" :
		"var(--text-color-muted, #666)";
my $html = &ui_tag('span', &html_escape($label), {
	'style' => 'display:inline-block;padding: 0.06em 0.6em;'.
		   'border:1px solid '.$color.';border-radius:999px;'.
		   'color:'.$color.';white-space:nowrap;'.
		   'line-height:1;font-size:0.9em;'.
		   'vertical-align: text-top;'
	});

# Keep the most actionable status line as the details summary and move the rest
# into muted supporting text.
my @details = @{$status->{'details'} || [ ]};
my $statusmsg;
if (@{$status->{'logs'} || [ ]} && @details) {
	$statusmsg = &status_message_details($status, pop(@details));
	}
else {
	$statusmsg = &status_message_details($status);
	}
if (@details) {
	$html .= &ui_br().&ui_tag('small',
		&html_join_escaped_lines(@details),
		{ 'style' => 'color:var(--text-color-muted, #666);'.
			     'white-space:pre-wrap;' });
	}
$html .= &ui_br().$statusmsg if ($statusmsg);
return $html;
}

# status_message_details(&status, [title])
# Displays service logs inline, but collapsed by default.
sub status_message_details
{
my ($status, $title) = @_;
my @logs = @{$status->{'logs'} || [ ]};
return "" if (!@logs);
my $state = $status->{'state'} || 'unknown';
my $color = $state eq 'skipped' ?
	"var(--warning-color, #b7791f)" :
	"var(--danger-color, #d33)";
my $content = &ui_tag('small',
	&html_join_escaped_lines(@logs),
	{ 'style' => 'color:'.$color.';white-space:pre-wrap;'.
		     'overflow-wrap:anywhere;line-height:1.35;'.
		     'display:block;margin-top:0.2em;'.
		     'max-width:100%;' });
my $summary = defined($title) && $title ne '' ?
	&ui_tag('small', &html_escape($title), {
		'style' => 'color:var(--text-color-muted, #666);'.
			   'white-space:pre-wrap;',
		}) :
	&html_escape($text{'status_messages'});
return &ui_details({
	'html' => 1,
	'title' => $summary,
	'class' => 'inline kea-status-details',
	'content' => $content,
	});
}

# status_details_style()
# Softens the native details arrow so it does not dominate status text.
sub status_details_style
{
return &ui_tag('style', <<'EOF');
details.inline.kea-status-details > summary:after {
	opacity: .4;
}
EOF
}

# error_text(text)
# Renders an inline error fragment for table cells.
sub error_text
{
my ($msg) = @_;
return &ui_tag('span', &html_escape($msg), {
	'style' => 'color:var(--danger-color, #d33);',
	});
}

# warning_lines(lines...)
# Renders warning text that can be embedded into table cells.
sub warning_lines
{
my @msgs = @_;
return "" if (!@msgs);
return &ui_tag('small',
	&html_join_escaped_lines(@msgs),
	{ 'style' => 'color:var(--warning-color, #b7791f);'.
		     'white-space:pre-wrap;' });
}

# scope_location_summary(&scope)
# Returns the interface or relay selector for a shared network/subnet.
sub scope_location_summary
{
my ($scope) = @_;
return $scope->{'interface'} if ($scope->{'interface'});
my @relays = &kea_relay_addresses($scope);
return join(", ", @relays) if (@relays);
return "";
}

# shared_summary(&shared-network, &subnets)
# Summarizes production-relevant shared-network state.
sub shared_summary
{
my ($shared, $subnets) = @_;
my @parts;
my $loc = &scope_location_summary($shared);
push(@parts, &html_escape($loc)) if ($loc ne '');
my @warnings;
push(@warnings, @$subnets == 0 ? $text{'warn_shared_empty'} :
				    $text{'warn_shared_single'})
	if (@$subnets < 2);
push(@parts, &warning_lines(@warnings)) if (@warnings);
return &html_join_br(@parts);
}

# subnet_warnings(&subnet, version)
# Returns warnings for subnet shapes that Kea accepts but admins should notice.
sub subnet_warnings
{
my ($sub, $ver) = @_;
my @warnings;
if ($ver == 4) {
	my $canonical = &kea_ipv4_canonical_subnet($sub->{'subnet'} || "");
	push(@warnings, &text('warn_subnet_noncanonical', $canonical))
		if ($canonical && $canonical ne ($sub->{'subnet'} || ""));
	}
my $pools = &kea_count_array($sub, 'pools');
my $reservations = &kea_count_array($sub, 'reservations');
push(@warnings, $text{'warn_subnet_no_leases'})
	if (!$pools && !$reservations);
return @warnings;
}

# subnet_link_cell(url, label, &subnet, version)
# Links subnet names only for users allowed to edit that DHCP version.
sub subnet_link_cell
{
my ($url, $label, $sub, $ver) = @_;
my $html = &kea_can_edit_dhcp(\%access, $ver) ?
	&ui_link($url, &html_escape($label)) :
	&html_escape($label);
my @warnings = &subnet_warnings($sub, $ver);
$html .= &ui_br().&warning_lines(@warnings) if (@warnings);
return $html;
}

# service_action_links()
# Returns header service actions according to current daemon state and ACLs.
sub service_action_links
{
my @links;
if ($access{'apply'}) {
	if (&kea_running_pids()) {
		push(@links, &ui_link("stop.cgi", $text{'index_stop'}));
		push(@links, &ui_link("restart.cgi", $text{'index_restart'}));
		}
	else {
		push(@links, &ui_link("start.cgi", $text{'index_start'}));
		}
	}
return &html_join_br(@links);
}

# config_cell(&component, file)
# Links known config files into the raw editor when ACLs allow manual edits.
sub config_cell
{
my ($c, $file) = @_;
return &ui_tag('i', &html_escape($text{'index_not_configured'})) if (!$file);
my $html = &ui_tag('tt', &html_escape($file));
return $html if (!$access{'manual'});
return $html if (!&kea_manual_edit_file($file));
return &ui_link("edit_text.cgi?file=".&urlize($file), $html);
}

# print_services_table()
# Displays daemon state and config summaries for all Kea components.
sub print_services_table
{
my @tdtags = ( undef, "width=25%", undef, undef, undef );
print &status_details_style();
print &ui_columns_start([
	$text{'col_service'},
	$text{'col_status'},
	$text{'col_config'},
	$text{'col_interfaces'},
	$text{'col_summary'} ], 100, 0,
	\@tdtags);

# Each row combines three sources of truth: configured module paths, live daemon
# state, and parsed config summaries.
foreach my $c (&kea_components()) {
	my $file = &kea_config_file($c);
	my $status = &kea_component_status($c);
	my ($root, $err) = &kea_read_component_config($c);
	my ($ifaces, $summary);
	if ($err) {
		$ifaces = "";
		$summary = &error_text($err);
		}
	else {
		$ifaces = $c->{'id'} =~ /^dhcp/ ?
			&html_escape(&kea_component_interfaces($root)) : "";
		if ($c->{'id'} =~ /^dhcp([46])$/ &&
		    &kea_dhcp_needs_interface_warning($root, $1)) {
			$ifaces .= &ui_br().
				   &ui_tag('small',
					&html_escape($text{'warn_interfaces_empty_short'}),
					{ 'style' => 'color:var(--warning-color, #b7791f)' });
			}
		$summary = &html_escape(&kea_component_summary($c, $root));
		}

	print &ui_columns_row([
		&html_escape($c->{'label'}),
		&status_badge($status),
		&config_cell($c, $file),
		$ifaces,
		$summary,
		], \@tdtags);
	}
print &ui_columns_end();
}

# print_action_buttons()
# Shows bottom editor shortcuts that are valid for the current ACL.
sub print_action_buttons
{
my @editable = &kea_editable_components();
return if (!@editable);
return if (!&kea_can_view_runtime(\%access) &&
	   !$access{'manual'} &&
	   !&kea_can_edit_dhcp(\%access, 4) &&
	   !&kea_can_edit_dhcp(\%access, 6) &&
	   !&kea_can_edit_ddns(\%access));
print &ui_hr();
print &ui_buttons_start();

# Global settings shortcuts are shown only when the backing config exists and
# the user can edit that protocol.
foreach my $ver (4, 6) {
	my $c = &kea_dhcp_component($ver);
	next if (!&kea_config_file($c) ||
		 !&kea_can_edit_dhcp(\%access, $ver));
	print &ui_buttons_row("edit_options.cgi",
		&text('index_global_settings', $ver),
		&text('index_global_settingsdesc', $ver),
		[ [ "version", $ver ] ]);
	}
my $ddns = &kea_component('ddns');
if (&kea_config_file($ddns) && &kea_can_edit_ddns(\%access)) {
	print &ui_buttons_row("edit_ddns.cgi",
		$text{'index_ddns_settings'},
		$text{'index_ddns_settingsdesc'});
	}
if (&kea_can_view_runtime(\%access)) {
	print &ui_buttons_row("runtime.cgi",
		$text{'index_runtime_status'},
		$text{'index_runtime_statusdesc'});
	}
if ($access{'manual'}) {
	print &ui_buttons_row("edit_text.cgi",
		$text{'index_edit_manual'},
		$text{'index_edit_manualdesc'});
	}
print &ui_buttons_end();
}

# print_ddns_tab()
# Displays the standalone DHCP-DDNS daemon configuration at module level.
sub print_ddns_tab
{
my $c = &kea_component('ddns');
my $can_edit = &kea_can_edit_ddns(\%access);
my ($root, $err) = &kea_read_component_config($c);
if ($err) {
	print &ui_alert_box(&html_escape($err), "danger", undef, undef, "");
	return;
	}

print &ui_div($text{'index_ddns_desc'});
print &kea_comment_loss_warning($c) if ($can_edit);

# The D2 overview deliberately pairs the standalone receiver with DHCPv4/DHCPv6
# sender state, because both sides must match before DNS updates flow.
print &ui_columns_start([
	$text{'ddns_area'},
	$text{'col_summary'} ], 100, 0,
	[ "width=25%", "width=75%" ]);
print &ui_columns_row([
	$text{'ddns_listener'},
	&ddns_listener_cell($root),
	]);
print &ui_columns_row([
	$text{'ddns_sender4'},
	&ddns_sender_cell(4, $root),
	]);
print &ui_columns_row([
	$text{'ddns_sender6'},
	&ddns_sender_cell(6, $root),
	]);
print &ui_columns_row([
	$text{'control_socket'},
	&ddns_control_socket_cell($root),
	]);
print &ui_columns_row([
	$text{'ddns_forward'},
	&ddns_domains_cell($root, 'forward-ddns'),
	]);
print &ui_columns_row([
	$text{'ddns_reverse'},
	&ddns_domains_cell($root, 'reverse-ddns'),
	]);
print &ui_columns_row([
	$text{'ddns_tsig_keys'},
	&text('ddns_count', &kea_count_array($root, 'tsig-keys')),
	]);
print &ui_columns_row([
	$text{'logging_loggers'},
	&text('ddns_count', &kea_count_array($root, 'loggers')),
	]);
print &ui_columns_end();
}

# ddns_listener_cell(&root)
# Summarizes the D2 listener endpoint and any listener safety warning.
sub ddns_listener_cell
{
my ($root) = @_;
my $target = &kea_ddns_listener_target($root);
return &ui_tag('i', &html_escape($text{'index_not_configured'}))
	if ($target eq '');
my @parts = (&ui_tag('tt', &html_escape($target)));
my $warn = &kea_ddns_listener_non_loopback($root) ?
	$text{'ddns_listener_warn'} :
	&kea_ddns_listener_non_default_loopback($root) ?
		$text{'ddns_listener_warn_loopback'} : "";
push(@parts, &ui_tag('span', $warn, {
	'style' => 'color:var(--warning-color, #b7791f)' }))
	if ($warn ne '');
return &html_join_br(@parts);
}

# ddns_sender_cell(version, &d2-root)
# Shows whether DHCPv4/DHCPv6 is configured to send updates to this D2 daemon.
sub ddns_sender_cell
{
my ($ver, $d2root) = @_;
my ($c, $root, $data, $err) = &kea_read_dhcp_config($ver);
return &ui_tag('span', &text('ddns_sender_unknown', $ver, &html_escape($err)),
	       { 'style' => 'color:var(--danger-color, #d33)' })
	if ($err);
my $sender = ref($root->{'dhcp-ddns'}) eq 'HASH' ?
	$root->{'dhcp-ddns'} : { };
return $text{'ddns_sender_disabled'} if (!$sender->{'enable-updates'});

my $host = $sender->{'server-ip'} || "";
my $port = defined($sender->{'server-port'}) ? $sender->{'server-port'} : "";
my $target = $host.($port ne '' ? ":".$port : "");
my $d2target = &kea_ddns_listener_target($d2root);
my @parts = ($text{'ddns_sender_enabled'});
push(@parts, &text('ddns_sender_target',
		   &ui_tag('tt', &html_escape($target))))
	if ($target ne '');
if ($target ne '' && $d2target ne '') {
	push(@parts, $target eq $d2target ?
		$text{'ddns_sender_match'} :
		&text('ddns_sender_mismatch',
		      &ui_tag('tt', &html_escape($d2target))));
	}
return &html_join_br(@parts);
}

# ddns_control_socket_cell(&root)
# Summarizes the DHCP-DDNS control socket from the daemon config.
sub ddns_control_socket_cell
{
my ($root) = @_;
my $socket = ref($root->{'control-socket'}) eq 'HASH' ?
	$root->{'control-socket'} : { };
my $type = $socket->{'socket-type'} || "";
my $name = $socket->{'socket-name'} || "";
return &ui_tag('i', &html_escape($text{'index_not_configured'}))
	if ($type eq '' && $name eq '');
return &ui_tag('tt', &html_escape(join(" ", grep { $_ ne '' } ($type, $name))));
}

# ddns_domains_cell(&root, section-name)
# Summarizes configured forward or reverse DDNS domains for the overview table.
sub ddns_domains_cell
{
my ($root, $section) = @_;
my $domains = &kea_ddns_domains($root, $section);
return &ui_tag('i', &html_escape($text{'index_empty'})) if (!@$domains);
return &html_join_br(map {
	my $name = $_->{'name'} || "";
	my $key = $_->{'key-name'} || "";
	my ($servers) = &kea_ddns_domain_server_fields($_);
	my @parts = (&html_escape($name));
	push(@parts, &html_escape($key)) if ($key ne '');
	push(@parts, &ui_tag('tt', &html_escape($servers))) if ($servers ne '');
	join(" &middot; ", @parts);
	} @$domains);
}

# print_dhcp_tab(4|6)
# Displays shared networks and subnets for one Kea DHCP daemon.
sub print_dhcp_tab
{
my ($ver) = @_;
my $can_edit = &kea_can_edit_dhcp(\%access, $ver);
my ($c, $root, $data, $err) = &kea_read_dhcp_config($ver);
if ($err) {
	print &ui_alert_box(&html_escape($err), "danger", undef, undef, "");
	return;
	}

print &ui_div($text{'index_dhcp'.$ver.'_desc'});
print &kea_comment_loss_warning($c) if ($can_edit);
print &ui_alert_box(&html_escape($text{'dhcp6_ra_warn'}), "warn", undef, undef, "")
	if ($ver == 6);
print &ui_alert_box(&text('warn_interfaces_empty',
			  &ui_tag('tt', 'interfaces-config')), "warn",
		    undef, undef, "")
	if (&kea_dhcp_needs_interface_warning($root, $ver));

# Shared networks and subnets share one delete endpoint but use separate forms
# so checked-table controls stay close to the table they act on.
my $shareds = &kea_shared_networks($root);
my @subnets = &kea_all_subnets($root, $ver);
my $shared_formno = $delete_formno;
print &ui_form_start("delete_objects.cgi", "post")
	if ($can_edit && @$shareds);
if ($can_edit && @$shareds) {
	$delete_formno++;
	print &ui_hidden("version", $ver);
	}

my @shared_links = @$shareds && $can_edit ?
	( &select_all_link("d_shared", $shared_formno),
	  &select_invert_link("d_shared", $shared_formno) ) : ( );
push(@shared_links, &ui_link("edit_shared.cgi?version=$ver&new=1",
			     $text{'index_add_shared'}))
	if ($can_edit);
print &ui_subheading($text{'index_shared_networks'});
print &ui_links_row(\@shared_links) if (@shared_links);
if (@$shareds) {
	print &ui_columns_start([
		($can_edit ? ( "" ) : ( )),
		$text{'col_name'}, $text{'col_subnets'}, $text{'col_options'},
		$text{'col_summary'} ], 100, 0,
		&shared_tdtags($ver));
	for(my $i=0; $i<@$shareds; $i++) {
		my $s = $shareds->[$i];
		my $subnets = &kea_subnet_list($root, $ver, $i);
		my $name = &kea_scope_name($s, &text('index_shared_num', $i+1));
		my @cols = (
			$can_edit ?
				&ui_link("edit_shared.cgi?version=$ver&idx=$i",
					 &html_escape($name)) :
				&html_escape($name),
			scalar(@$subnets),
			&kea_count_array($s, 'option-data'),
			&shared_summary($s, $subnets),
			);
		if ($can_edit) {
			print &ui_checked_columns_row(\@cols, &shared_tdtags($ver),
						      "d_shared", $i);
			}
		else {
			print &ui_columns_row(\@cols);
			}
		}
	print &ui_columns_end();
	}
else {
	print &ui_div($can_edit ?
		$text{'index_empty_shared_add'} :
		$text{'index_empty_shared'});
	}
if ($can_edit && @$shareds) {
	print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
	}

my $subnet_formno = $delete_formno;
print &ui_form_start("delete_objects.cgi", "post")
	if ($can_edit && @subnets);
if ($can_edit && @subnets) {
	$delete_formno++;
	print &ui_hidden("version", $ver);
	}
my @subnet_links = @subnets && $can_edit ?
	( &select_all_link("d_subnet", $subnet_formno),
	  &select_invert_link("d_subnet", $subnet_formno) ) : ( );
push(@subnet_links, &ui_link("edit_subnet.cgi?version=$ver&new=1",
			     $text{'index_add_subnet'}))
	if ($can_edit);
print &ui_subheading($text{'index_subnets'});
print &ui_links_row(\@subnet_links) if (@subnet_links);
if (@subnets) {
	print &ui_columns_start(&subnet_headings($ver), 100, 0,
		&subnet_tdtags($ver));
	foreach my $row (@subnets) {
		my $sub = $row->{'subnet'};
		my $shared = $row->{'shared'} ?
			&kea_scope_name($row->{'shared'}, "") : "";
		my $url = "edit_subnet.cgi?version=$ver&idx=$row->{'idx'}".
			  ($row->{'sidx'} ne '' ? "&sidx=$row->{'sidx'}" : "");
		my @cols = (
			$sub->{'id'} || "",
			&subnet_link_cell($url, $sub->{'subnet'} || "", $sub, $ver),
			&html_escape($shared),
			&kea_count_array($sub, 'pools'),
			);
		push(@cols, &kea_count_array($sub, 'pd-pools')) if ($ver == 6);
		push(@cols, &kea_count_array($sub, 'reservations'));
		push(@cols, &kea_count_array($sub, 'option-data'));
		if ($can_edit) {
			print &ui_checked_columns_row(\@cols, &subnet_tdtags($ver),
						      "d_subnet",
						      $row->{'sidx'}.":".$row->{'idx'});
			}
		else {
			print &ui_columns_row(\@cols);
			}
		}
	print &ui_columns_end();
	}
else {
	print &ui_div($can_edit ?
		$text{'index_empty_subnets_add'} :
		$text{'index_empty_subnets'});
	}
if ($can_edit && @subnets) {
	print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
	}
}

# shared_tdtags(version)
# Returns column width hints for the shared-network table.
sub shared_tdtags
{
my ($ver) = @_;
return &kea_can_edit_dhcp(\%access, $ver) ?
	[ "width=5", "width=30%", "width=15%", "width=15%", "width=40%" ] :
	[ "width=30%", "width=15%", "width=15%", "width=40%" ];
}

# subnet_headings(version)
# Returns protocol-specific headings for the subnet table.
sub subnet_headings
{
my ($ver) = @_;
return [
	(&kea_can_edit_dhcp(\%access, $ver) ? ( "" ) : ( )),
	$text{'col_id'}, $text{'col_subnet'}, $text{'col_shared'},
	$text{'col_pools'},
	($ver == 6 ? ( $text{'col_pd_pools'} ) : ( )),
	$text{'col_reservations'}, $text{'col_options'} ];
}

# subnet_tdtags(version)
# Returns column width hints for the subnet table.
sub subnet_tdtags
{
my ($ver) = @_;
if ($ver == 6) {
	return &kea_can_edit_dhcp(\%access, $ver) ?
		[ "width=5", "width=7%", "width=27%", "width=18%",
		  "width=10%", "width=10%", "width=11%", "width=12%" ] :
		[ "width=7%", "width=28%", "width=20%", "width=10%",
		  "width=10%", "width=12%", "width=13%" ];
	}
return &kea_can_edit_dhcp(\%access, $ver) ?
	[ "width=5", "width=8%", "width=30%", "width=20%",
	  "width=12%", "width=12%", "width=13%" ] :
	[ "width=8%", "width=32%", "width=22%", "width=12%",
	  "width=13%", "width=13%" ];
}
