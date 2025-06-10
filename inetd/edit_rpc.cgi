#!/usr/local/bin/perl
# edit_rpc.cgi
# Display a form for editing a RPC service

require './inetd-lib.pl';
&ReadParse();

if ($in{'new'}) {
	&ui_print_header(undef, $text{'editrpc_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'editrpc_title2'}, "");
	@rpc = @{(&list_rpcs())[$in{'rpos'}]};
	if ($in{'ipos'} =~ /\d/) {
		@inet = @{(&list_inets())[$in{'ipos'}]};
		}
	}

print &ui_form_start("save_rpc.cgi", "post");
if (@rpc) {
        print &ui_hidden("rpos", $in{'rpos'});
        print &ui_hidden("ipos", $in{'ipos'});
        }
print &ui_table_start($text{'editrpc_detail'}, "width=100%", 4);

# Service name
print &ui_table_row($text{'editrpc_prgname'},
	&ui_textbox("name", $rpc[1], 20));

# RPC number
print &ui_table_row($text{'editrpc_prgnum'},
	&ui_textbox("number", $rpc[2], 7));

# Alias names
print &ui_table_row($text{'editrpc_aliase'},
        &ui_textarea("aliases", join("\n", split(/\s+/, $rpc[3])), 3, 20));

print &ui_table_end();

if ($config{'rpc_inetd'}) {
	print &ui_table_start($text{'editrpc_server'}, "width=100%", 4);

	# Server enabled?
	print &ui_table_row($text{'editrpc_act'},
		&ui_radio("act", $inet[1] ? 2 : @inet && !$inet[1] ? 1 : 0,
			  [ [ 0, $text{'editrpc_noassigned'} ],
			    [ 1, $text{'editrpc_disable'} ],
			    [ 2, $text{'editrpc_enable'} ] ]), 3);

	# RPC versions
	if ($inet[3] =~ /^[^\/]+\/([0-9]+)\-([0-9]+)$/) {
		$vfrom = $1; $vto = $2;
		}
	elsif ($inet[3] =~ /^[^\/]+\/([0-9]+)$/) {
		$vfrom = $1; $vto = $1;
		}
	else { $vfrom = $vto = ""; }
	print &ui_table_row($text{'editrpc_version'},
		&ui_textbox("vfrom", $vfrom, 2)." - ".
		&ui_textbox("vto", $vto, 2));

	# Socket type
	print &ui_table_row($text{'editrpc_socket'},
		&ui_select("type", $inet[4] || "stream",
			   [ [ "stream", $text{'editrpc_stream'} ],
			     [ "dgram", $text{'editrpc_dgram'} ],
			     [ "tli", $text{'editrpc_tli'} ] ]));

	# Protocol
	$inet[5] =~ /^[^\/]+\/(.*)$/;
	if ($1 eq "*") { @usedpr = split(/\s+/, $config{'rpc_protocols'}); }
	else { @usedpr = split(/,/, $1); }
	@cbs = ( );
	foreach $upr (split(/\s+/, $config{'rpc_protocols'})) {
		push(@cbs, &ui_checkbox("protocols", $upr, uc($upr),
					&indexof($upr, @usedpr) >= 0));
		}
	print &ui_table_row($text{'editrpc_protocol'}, join(" ", @cbs));

	# RPC server
	$qm = ($inet[8] =~ s/^\?//);
	if (!$config{'no_internal'}) {
		$server = &ui_radio("internal", $inet[8] eq "internal" ? 1 : 0,
			    [ [ 1, $text{'editrpc_internal'} ],
			      [ 0, &ui_textbox("program", $inet[8] ne "internal" || !@inet ? $inet[8] : "", 40) ] ]);
		}
	else {
		$server = &ui_textbox("program", @inet ? $inet[8] : "", 40);
		}
	$server .= &file_chooser_button("program", 0);
	if ($config{'qm_mode'}) {
		$server .= "<br>".
			   &ui_checkbox("qm", 1, $text{'editserv_qm'}, $qm);
		}
	print &ui_table_row($text{'editrpc_server'}, $server, 3);

	# RPC command
	if (!$config{'no_internal'}) {
		print &ui_table_row($text{'editrpc_command'},
			&ui_textbox("args", $inet[8] eq "internal" ? "" : $inet[9], 40));
	} else {
		print &ui_table_row($text{'editrpc_command'},
			&ui_textbox("args", $inet[9], 40));
		}

	# Extract wait mode and group
	if ($inet[6] =~ /^(\S+)\.(\d+)$/) { $waitmode = $1; $permin = $2; }
	else { $waitmode = $inet[6]; $permin = -1; }
	if ($inet[7] =~ /^(\S+)\.(\S+)$/) { $user = $1; $group = $2; }
	else { $user = $inet[7]; undef($group); }

	# Wait for completion?
	print &ui_table_row($text{'editrpc_waitmode'},
		&ui_radio("wait", $waitmode || "wait",
			  [ [ "wait", $text{'editrpc_wait'} ],
			    [ "nowait", $text{'editrpc_nowait'} ] ]));

	# Run as user
	print &ui_table_row($text{'editrpc_execasuser'},
		&ui_user_textbox("user", $user));

	if ($config{'extended_inetd'}) {
		# Max per minute
		print &ui_table_row($text{'editrpc_max'},
			&ui_opt_textbox("permin", $permin<0 ? "" : $permin, 5,
					$text{'editrpc_default'}));

		# Run as group
		print &ui_table_row($text{'editrpc_execasgrp'},
			&ui_opt_textbox("group", $group, 13, $text{'default'}).
			&group_chooser_button("group"));
		}

	print &ui_table_end();
	}

if (!$in{'new'}) {
        print &ui_form_end([ [ undef, $text{'save'} ],
                             [ 'delete', $text{'delete'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}

&ui_print_footer("", $text{'index_list'});

