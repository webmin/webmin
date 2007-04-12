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

print "<form action=\"save_serv.cgi\" method=post>\n";
if (@serv) {
	print "<input type=hidden name=spos value=$in{'spos'}>\n";
	print "<input type=hidden name=ipos value=$in{'ipos'}>\n";
	}
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'editserv_detail'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td nowrap><b>$text{'editserv_name'}</b></td>\n";
print "<td><input size=20 name=name value=\"$serv[1]\"></td>\n";

print "<td nowrap><b>$text{'editserv_port'}</b></td>\n";
print "<td nowrap><input size=10 name=port value=\"$serv[2]\"></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'editrpc_protocol'}</b></td>\n";
print "<td valign=top><select name=protocol>\n";
foreach $p (&list_protocols()) {
	printf "<option value=$p %s>%s %s\n",
		$serv[3] eq $p || (!@serv && $p eq "tcp") ? "selected" : "",
		uc($p), $prot_name{$p} ? "($prot_name{$p})" : "";
	}
print "</select></td>\n";

print "<td valign=top><b>$text{'editrpc_aliase'}</b></td>\n";
printf "<td valign=top><textarea name=aliases ".
       "rows=3 cols=20>%s</textarea></td> </tr>\n",
	join("\n", split(/\s+/, $serv[4]));

print "</table></td> </tr></table><p>\n";

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

print "<tr> <td><b>$text{'editserv_program'}</b></td>\n";
print "<td colspan=3>";
if (!$config{'no_internal'}) {
	printf "<input type=radio name=serv value=1 %s>\n",
		$inet[8] eq "internal" ? "checked" : "";
	print "$text{'editserv_inetd'}</td> </tr>\n";
	}

$qm = ($inet[8] =~ s/^\?//);
$tcpd = (-x $config{'tcpd_path'} && $inet[8] eq $config{'tcpd_path'});
print "<tr> <td></td>\n";
print "<td colspan=3>";
if (!$config{'no_internal'}) {
	printf "<input type=radio name=serv value=2 %s> $text{'editrpc_command'}\n",
		$inet[8] ne "internal" && !$tcpd ? "checked" : "";
	printf "<input name=program size=30 value=\"%s\">\n",
		$inet[8] ne "internal" && !$tcpd ? $inet[8] : "";
	print &file_chooser_button("program", 0);
	printf "$text{'editserv_args'} <input name=args size=30 value=\"%s\">\n",
 	       $inet[5] ne "internal" && !$tcpd ? $inet[9] : "";

} else {
	printf "<input type=radio name=serv value=2 %s> $text{'editrpc_command'}\n",
		!$tcpd ? "checked" : "";
	printf "<input name=program size=30 value=\"%s\">\n",
		!$tcpd ? $inet[8] : "";
	print &file_chooser_button("program", 0);
	printf "$text{'editserv_args'} <input name=args size=30 value=\"%s\">\n",
        	!$tcpd ? $inet[9] : "";
	}
if ($config{'qm_mode'}) {
	print "<br>","&nbsp;" x 5;
	printf "<input type=checkbox name=qm value=1 %s> %s\n",
		$qm ? "checked" : "", $text{'editserv_qm'};
	}
print "</td> </tr>\n";

if (-x $config{'tcpd_path'}) {
	print "<tr> <td></td>\n";
	printf "<td colspan=3><input type=radio name=serv value=3 %s>\n",
		$tcpd ? "checked" : "";
 	print "$text{'editserv_wrapper'}\n";
	$inet[9] =~ /^(\S+)\s*(.*)$/;
	printf "<input name=tcpd size=15 value=\"%s\">\n", $tcpd ? $1 : "";
	printf "$text{'editserv_args'} <input name=args2 size=30 value=\"%s\"></td> </tr>\n",
		$tcpd ? $2 : "";
	}

@op1 = split(/[:\.\/]/, $inet[6]);
@op2 = split(/[:\.\/]/, $inet[7]);
if ($inet[7] =~ /\// && $inet[7] !~ /:/) {
	# class but no group!
	splice(@op2, 1, 0, undef);
	}
print "<tr> <td nowrap><b>$text{'editrpc_waitmode'}</b></td> <td nowrap>\n";
printf "<input type=radio name=wait value=wait %s> $text{'editrpc_wait'}\n",
	$op1[0] eq "wait" ? "checked" : "";
printf "<input type=radio name=wait value=nowait %s> $text{'editrpc_nowait'}</td>\n",
	$op1[0] ne "wait" ? "checked" : "";

print "<td nowrap><b>$text{'editrpc_execasuser'}</b></td>\n";
print "<td nowrap><input name=user size=8 value=\"$op2[0]\"> ",
      &user_chooser_button("user", 0),"</td> </tr>\n";

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

print "</table></td></tr></table>\n";
if (!$in{'new'}) {
	print "<table width=100%>\n";
	print "<tr> <td><input type=submit value=$text{'index_save'}></td>\n";
	print "</form><form action=\"delete_serv.cgi\">\n";
	print "<input type=hidden name=spos value=\"$in{'spos'}\">\n";
	print "<input type=hidden name=ipos value=\"$in{'ipos'}\">\n";
	print "<td align=right><input type=submit value=$text{'index_delete'}></td> </tr>\n";
	print "</form></table><p>\n";
	}
else {
	print "<input type=submit value=$text{'index_create'}></form><p>\n";
	}

&ui_print_footer("", $text{'index_list'});
