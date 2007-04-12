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

print "<form action=\"save_rpc.cgi\" method=post>\n";
if (@rpc) {
	print "<input type=hidden name=rpos value=$in{'rpos'}>\n";
	print "<input type=hidden name=ipos value=$in{'ipos'}>\n";
	}
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'editrpc_detail'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td nowrap><b>$text{'editrpc_prgname'}</b></td>\n";
print "<td><input size=10 name=name value=\"$rpc[1]\"></td>\n";

print "<td><b>$text{'editrpc_prgnum'}</b></td>\n";
print "<td><input size=7 name=number value=\"$rpc[2]\"></td> </tr>\n";

print "<tr> <td><b>$text{'editrpc_aliase'}</b></td> <td colspan=3>\n";
print "<input size=40 name=aliases value=\"$rpc[3]\"></td> </tr>\n";

print "</table></td></tr></table><p>\n";

if ($config{'rpc_inetd'}) {
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'editrpc_server'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";

	print "<tr> <td colspan=4>\n";
	printf "<input type=radio name=act value=0 %s> $text{'editrpc_noassigned'}\n",
		@inet ? "" : "checked";
	printf "<input type=radio name=act value=1 %s> $text{'editrpc_disable'}\n",
		@inet && !$inet[1] ? "checked" : "";
	printf "<input type=radio name=act value=2 %s> $text{'editrpc_enable'}\n",
		$inet[1] ? "checked" : "";
	print "</td> </tr>\n";

	print "<td><b>$text{'editrpc_version'}</b></td>\n";
	if ($inet[3] =~ /^[^\/]+\/([0-9]+)\-([0-9]+)$/) {
		$vfrom = $1; $vto = $2;
		}
	elsif ($inet[3] =~ /^[^\/]+\/([0-9]+)$/) {
		$vfrom = $1; $vto = $1;
		}
	else { $vfrom = $vto = ""; }
	print "<td><input size=1 name=vfrom value=\"$vfrom\"> -\n";
	print "<input size=1 name=vto value=\"$vto\"></td>\n";

	print "<td><b>$text{'editrpc_socket'}</b></td>\n";
	print "<td><select name=type>\n";
	printf "<option value=stream %s>Stream\n",
		$inet[4] eq "stream" || !@inet ? "selected" : "";
	printf "<option value=dgram %s>Datagram\n",
		$inet[4] eq "dgram" ? "selected" : "";
	printf "<option value=tli %s>TLI\n",
		$inet[4] eq "tli" ? "selected" : "";
	print "</select></td> </tr>\n";

	print "<tr> <td><b>$text{'editrpc_protocol'}</b></td>\n";
	$inet[5] =~ /^[^\/]+\/(.*)$/;
	if ($1 eq "*") { @usedpr = split(/\s+/, $config{'rpc_protocols'}); }
	else { @usedpr = split(/,/, $1); }
	print "<td colspan=3>\n";
	foreach $upr (split(/\s+/, $config{rpc_protocols})) {
		printf "<input name=protocols type=checkbox value=\"$upr\" %s>".
		       " $upr\n", &indexof($upr,@usedpr)<0?"":"checked";
		}
	print "</td> </tr>\n";

	$qm = ($inet[8] =~ s/^\?//);
	print "<tr> <td nowrap><b>$text{'editrpc_server'}</b></td>\n";
	if (!$config{'no_internal'}) {
		printf "<td colspan=3><input type=radio name=internal value=1 %s> $text{'editrpc_internal'}\n",
			$inet[8] eq "internal" ? "checked" : "";
		printf "<input type=radio name=internal value=0 %s>\n",
			$inet[8] ne "internal" || !@inet ? "checked" : "";
		printf "<input name=program size=40 value=\"%s\">\n",
		$inet[8] ne "internal" || !@inet ? $inet[8] : "";
	} else {
		printf "<td colspan=3>\n";
		printf "<input name=program size=40 value=\"%s\">\n",
			@inet ? $inet[8] : "";
		}
	print &file_chooser_button("program", 0);
	if ($config{'qm_mode'}) {
		print "<br>","&nbsp;" x 5;
		printf "<input type=checkbox name=qm value=1 %s> %s\n",
			$qm ? "checked" : "", $text{'editserv_qm'};
		}
	print "</td> </tr>\n";

	print "<tr> <td nowrap><b>$text{'editrpc_command'}</b></td> <td colspan=3>\n";
	if (!$config{'no_internal'}) {
		printf "<input name=args size=40 value=\"%s\"></td> </tr>\n",
			$inet[8] eq "internal" ? "" : $inet[9];
	} else {
		printf "<input name=args size=40 value=\"%s\"></td> </tr>\n",
			$inet[9];
		}
	if ($inet[6] =~ /^(\S+)\.(\d+)$/) { $waitmode = $1; $permin = $2; }
	else { $waitmode = $inet[6]; $permin = -1; }
	if ($inet[7] =~ /^(\S+)\.(\S+)$/) { $user = $1; $group = $2; }
	else { $user = $inet[7]; undef($group); }

	print "<tr> <td nowrap><b>$text{'editrpc_waitmode'}</b></td>\n";
	printf "<td nowrap><input type=radio name=wait value=wait %s> $text{'editrpc_wait'}\n",
		$waitmode eq "wait" || !@inet ? "checked" : "";
	printf "<input type=radio name=wait value=nowait %s> $text{'editrpc_nowait'}</td>\n",
		$waitmode eq "nowait" ? "checked" : "";

	print "<td nowrap><b>$text{'editrpc_execasuser'}</b></td>\n";
	print "<td nowrap><input name=user size=8 value=\"$user\"> ",
	      &user_chooser_button("user", 0),"</td> </tr>\n";

	if ($config{extended_inetd}) {
		print "<tr> <td nowrap><b>$text{'editrpc_max'}</b></td> <td nowrap>\n";
		printf "<input type=radio name=permin_def value=1 %s> $text{'editrpc_default'}\n",
			$permin<0 ? "checked" : "";
		printf "&nbsp; <input type=radio name=permin_def value=0 %s>\n",
			$permin<0 ? "" : "checked";
		printf "<input name=permin size=5 value=\"%s\"></td>\n",
			$permin<0 ? "" : $permin;

		print "<td nowrap><b>$text{'editrpc_execasgrp'}</b></td>\n";
		print "<td nowrap><select name=group>\n";
		printf "<option value=\"\" %s> $text{'editrpc_default'}",
			$group ? "" : "selected";
		setgrent();
		while(@ginfo = getgrent()) {
			printf "<option value=\"$ginfo[0]\" %s>$ginfo[0]\n",
				$ginfo[0] eq $group ? "selected" : "";
			}
		print "</select></td> </tr>\n";
		endgrent() if ($gconfig{'os_type'} ne 'hpux');
		}

	print "</table></td></tr></table><p>\n";
	}

if (@rpc) {
	print "<table width=100%>\n";
	print "<tr> <td><input type=submit value=$text{'index_save'}></td>\n";
	print "</form><form action=\"delete_rpc.cgi\">\n";
	print "<input type=hidden name=rpos value=\"$in{'rpos'}\">\n";
	print "<input type=hidden name=ipos value=\"$in{'ipos'}\">\n";
	print "<td align=right><input type=submit value=$text{'index_delete'}></td> </tr>\n";
	print "</form></table><p>\n";
	}
else {
	print "<input type=submit value=$text{'index_create'}></form><p>\n";
	}

&ui_print_footer("", $text{'index_list'});

