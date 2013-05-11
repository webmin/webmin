#!/usr/local/bin/perl
# edit_inet.cgi
# Display a form for editing or creating an internet service

require './inetd-lib.pl';
&ReadParse();

if ($in{'new'}) {
	&ui_print_header(undef, $text{'editserv_title1'}, "");
	}
else {
	local @servs = &list_services();
	local @inets = &list_inets();
	&ui_print_header(undef, $text{'editserv_title2'}, "");
	if (defined($in{'name'})) {
		local $i;
		for($i=0; $i<@servs; $i++) {
			$in{'spos'} = $i if ($servs[$i]->[1] eq $in{'name'} &&
					     $servs[$i]->[3] eq $in{'proto'});
			}
		defined($in{'spos'}) || &error($text{'editserv_ename'});
		for($i=0; $i<@inets; $i++) {
			$in{'ipos'} = $i if ($inets[$i]->[3] eq $in{'name'} &&
					     $inets[$i]->[5] eq $in{'proto'});
			}
		}
	@serv = @{$servs[$in{'spos'}]};
	if ($in{'ipos'} =~ /\d/) {
		@inet = @{$inets[$in{'ipos'}]};
		}
	}

print &ui_form_start("save_serv.cgi", "post");
if (@serv) {
	print &ui_hidden("spos", $in{'spos'});
	print &ui_hidden("ipos", $in{'ipos'});
	}
print &ui_table_start($text{'editserv_detail'}, "width=100%", 4);

# Service name
print &ui_table_row($text{'editserv_name'},
	&ui_textbox("name", $serv[1], 20));

# Port number
print &ui_table_row($text{'editserv_port'},
	&ui_textbox("port", $serv[2], 10));

# Protocol
print &ui_table_row($text{'editrpc_protocol'},
	&ui_select("protocol", @serv ? $serv[3] : "tcp",
		   [ map { [ $_, uc($_).($prot_name{$_} ? " ($prot_name{$_})"
						      : "") ] }
			 &list_protocols() ]));

# Name aliases
print &ui_table_row($text{'editrpc_aliase'},
	&ui_textarea("aliases", join("\n", split(/\s+/, $serv[4])), 3, 20));

print &ui_table_end();

print &ui_table_start($text{'editrpc_server'}, "width=100%", 4);

# Server enabled?
print &ui_table_row(undef,
	&ui_radio("act", $inet[1] ? 2 : @inet && !$inet[1] ? 1 : 0,
		  [ [ 0, $text{'editrpc_noassigned'} ],
		    [ 1, $text{'editrpc_disable'} ],
		    [ 2, $text{'editrpc_enable'} ] ]), 3);
@opts = ( );

# Handled internally
if (!$config{'no_internal'}) {
	push(@opts, [ 1, $text{'editserv_inetd'} ]);
	}

$qm = ($inet[8] =~ s/^\?//);
$tcpd = (-x $config{'tcpd_path'} && $inet[8] eq $config{'tcpd_path'});
$mode = $inet[8] eq "internal" && !$config{'no_internal'} ? 1 : $tcpd ? 3 : 2;
push(@opts, [ 2, $text{'editrpc_command'},
	      &ui_textbox("program", $mode == 2 ? $inet[8] : "", 30).
	      &file_chooser_button("program", 0)." ".
	      $text{'editserv_args'}." ".
	      &ui_textbox("args", $mode == 2 ? $inet[9] : "", 30) ]);
if ($config{'qm_mode'}) {
	# Server program doesn't exist
	$opts[$#opts]->[2] .= "<br>\n".
			      &ui_checkbox("qm", 1, $text{'editserv_qm'}, $qm);
	}

if (-x $config{'tcpd_path'}) {
	($tcpserv, $tcpargs) = $tcpd && $inet[9] =~ /^(\S+)\s*(.*)$/ ?
				($1, $2) : ( );
	push(@opts, [ 3, $text{'editserv_wrapper'},
		      &ui_textbox("tcpd", $tcpserv, 15)." ".
		      $text{'editserv_args'}." ".
		      &ui_textbox("args2", $tcpargs, 15) ]);
	}

print &ui_table_row($text{'editserv_program'},
	&ui_radio_table("serv", $mode, \@opts), 3);

@op1 = split(/[:\.\/]/, $inet[6]);
@op2 = split(/[:\.\/]/, $inet[7]);
if ($inet[7] =~ /\// && $inet[7] !~ /:/) {
	# class but no group!
	splice(@op2, 1, 0, undef);
	}
print &ui_table_row($text{'editrpc_waitmode'},
	&ui_radio("wait", $op1[0] eq "wait" ? "wait" : "nowait",
		  [ [ "wait", $text{'editrpc_wait'} ],
		    [ "nowait", $text{'editrpc_nowait'} ] ]));

print &ui_table_row($text{'editrpc_execasuser'},
	&ui_userbox("user", $op2[0]));

if ($config{'extended_inetd'} == 1) {
	# Display max per minute and group options
	# This is for systems like Linux
	print "<tr> <td nowrap><b>$text{'editrpc_max'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=permin_def value=1 %s> $text{'editrpc_default'}\n",
		@op1 < 2 ? "checked" : "";
	printf "&nbsp; <input type=radio name=permin_def value=0 %s>\n",
		@op1 < 2 ? "" : "checked";
	printf "<input name=permin size=5 value=\"%s\"></td>\n",
		@op1 < 2 ? "" : $op1[1];

	print "<td nowrap><b>$text{'editrpc_execasgrp'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=group_def value=1 %s> %s\n",
		$op2[1] ? "" : "checked", $text{'default'};
	printf "<input type=radio name=group_def value=0 %s>\n",
		$op2[1] ? "checked" : "";
	print &unix_group_input("group", $op2[1]),"</td> </tr>\n";
	}
elsif ($config{'extended_inetd'} == 2) {
	# Display max child, max per minute, group and login class options
	# This is for systems like FreeBSD
	print "<tr> <td nowrap><b>$text{'editrpc_max'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=permin_def value=1 %s> $text{'editrpc_default'}\n",
		@op1 < 3 ? "checked" : "";
	printf "&nbsp; <input type=radio name=permin_def value=0 %s>\n",
		@op1 < 3 ? "" : "checked";
	printf "<input name=permin size=5 value=\"%s\"></td>\n",
		@op1 < 3 ? "" : $op1[2];

	print "<td nowrap><b>$text{'editrpc_execasgrp'}</b></td>\n";
	print "<td nowrap><select name=group>\n";
	printf "<option value=\"\" %s> $text{'editrpc_default'}",
		$op2[1] ? "" : "selected";
	setgrent();
	while(@ginfo = getgrent()) {
		printf "<option value=\"$ginfo[0]\" %s>$ginfo[0]\n",
			$ginfo[0] eq $op2[1] ? "selected" : "";
		}
	print "</select></td> </tr>\n";
	endgrent() if ($gconfig{'os_type'} ne 'hpux');

	print "<tr> <td nowrap><b>$text{'editserv_maxchild'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=child_def value=1 %s> $text{'editrpc_default'}\n",
		@op1 < 2 ? "checked" : "";
	printf "&nbsp; <input type=radio name=child_def value=0 %s>\n",
		@op1 < 2 ? "" : "checked";
	printf "<input name=child size=5 value=\"%s\"></td>\n",
		@op1 < 2 ? "" : $op1[1];

	print "<td nowrap><b>$text{'editserv_execlogin'}</b></td>\n";
	print "<td><input name=class size=10 value=\"$op2[2]\"></td> </tr>\n";
	}

print &ui_table_end();
if (!$in{'new'}) {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}

&ui_print_footer("", $text{'index_list'});
