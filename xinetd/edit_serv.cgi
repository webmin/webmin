#!/usr/local/bin/perl
# edit_serv.cgi
# Display a form for editing or creating an internet service

require './xinetd-lib.pl';
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'serv_create'}, "");
	}
else {
	&ui_print_header(undef, $text{'serv_edit'}, "");
	@conf = &get_xinetd_config();
	$xinet = $conf[$in{'idx'}];
	$q = $xinet->{'quick'};
	($defs) = grep { $_->{'name'} eq 'defaults' } @conf;
	foreach $m (@{$defs->{'members'}}) {
		$ddisable{$m->{'value'}}++ if ($m->{'name'} eq 'disabled');
		}
	}

print "<form action=save_serv.cgi method=post>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'serv_header1'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'serv_id'}</b></td>\n";
printf "<td><input name=id size=10 value='%s'></td>\n",
	$xinet->{'value'};

$id = $q->{'id'}->[0] || $xinet->{'value'};
$dis = $q->{'disable'}->[0] eq 'yes' || $ddisable{$id};
print "<td><b>$text{'serv_enabled'}</b></td>\n";
printf "<td><input type=radio name=disable value=0 %s> %s\n",
	$dis ? '' : 'checked', $text{'yes'};
printf "<input type=radio name=disable value=1 %s> %s</td> </tr>\n",
	$dis ? 'checked' : '', $text{'no'};

print "<td><b>$text{'serv_bind'}</b></td>\n";
printf "<td><input type=radio name=bind_def value=1 %s> %s\n",
	$q->{'bind'} ? '' : 'checked', $text{'serv_bind_def'};
printf "<input type=radio name=bind_def value=0 %s>\n",
	$q->{'bind'} ? 'checked' : '';
printf "<input name=bind size=20 value='%s'></td>\n",
	$q->{'bind'}->[0];

print "<td><b>$text{'serv_port'}</b></td>\n";
printf "<td><input type=radio name=port_def value=1 %s> %s\n",
	$q->{'port'} ? '' : 'checked', $text{'serv_port_def'};
printf "<input type=radio name=port_def value=0 %s>\n",
	$q->{'port'} ? 'checked' : '';
printf "<input name=port size=8 value='%s'></td> </tr>\n",
	$q->{'port'}->[0];

print "<tr> <td><b>$text{'serv_sock'}</b></td>\n";
print "<td><select name=sock>\n";
foreach $s ('stream', 'dgram', 'raw', 'seqpacket') {
	printf "<option value=%s %s>%s\n",
		$s, $q->{'socket_type'}->[0] eq $s ? 'selected' : '',
		$text{"sock_$s"};
	}
print "</select></td>\n";

print "<td><b>$text{'serv_proto'}</b></td>\n";
print "<td><select name=proto>\n";
foreach $p ('', &list_protocols()) {
	printf "<option value='%s' %s>%s\n",
		$p, $q->{'protocol'}->[0] eq $p ? 'selected' : '',
		$text{"proto_$p"} ? $text{"proto_$p"} : uc($p);
	}
print "</select></td> </tr>\n";

print "</table></td></tr></table><p>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'serv_header2'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

$prog = &indexof('INTERNAL', @{$q->{'type'}}) >= 0 ? 0 :
	$q->{'redirect'} ? 2 : 1;
print "<tr> <td valign=top><b>$text{'serv_prog'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=prog value=0 %s> %s<br>\n",
	$prog == 0 ? 'checked' : '', $text{'serv_internal'};
printf "<input type=radio name=prog value=1 %s> %s\n",
	$prog == 1 ? 'checked' : '', $text{'serv_server'};
printf "<input name=server size=50 value='%s'><br>\n",
	join(" ", $q->{'server'}->[0], @{$q->{'server_args'}});
printf "<input type=radio name=prog value=2 %s> %s\n",
	$prog == 2 ? 'checked' : '', $text{'serv_redirect'};
printf "<input name=rhost size=20 value='%s'> %s\n",
	$prog == 2 ? $q->{'redirect'}->[0] : "", $text{'serv_rport'};
printf "<input name=rport size=6 value='%s'></td> </tr>\n",
	$prog == 2 ? $q->{'redirect'}->[1] : "";

print "<tr> <td><b>$text{'serv_user'}</b></td>\n";
printf "<td><input name=user size=10 value='%s'> %s</td>\n",
	$q->{'user'}->[0], &user_chooser_button('user');

print "<td><b>$text{'serv_group'}</b></td>\n";
printf "<td><input type=radio name=group_def value=1 %s> %s\n",
	$q->{'group'} ? '' : 'checked', $text{'serv_group_def'};
printf "<input type=radio name=group_def value=0 %s>\n",
	$q->{'group'} ? 'checked' : '';
printf "<input name=group size=10 value='%s'> %s</td> </tr>\n",
	$q->{'group'}->[0], &group_chooser_button('group');

print "<tr> <td><b>$text{'serv_wait'}</b></td>\n";
printf "<td><input type=radio name=wait value=1 %s> %s\n",
	$q->{'wait'}->[0] eq 'yes' ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=wait value=0 %s> %s</td>\n",
	$q->{'wait'}->[0] eq 'yes' ? '' : 'checked', $text{'no'};

$inst = uc($q->{'instances'}->[0]) eq 'UNLIMITED' ? '' : $q->{'instances'}->[0];
print "<td><b>$text{'serv_inst'}</b></td>\n";
printf "<td><input type=radio name=inst_def value=1 %s> %s\n",
	$inst ? '' : 'checked', $text{'serv_inst_def'};
printf "<input type=radio name=inst_def value=0 %s>\n",
	$inst ? 'checked' : '';
printf "<input name=inst size=5 value='%s'></td> </tr>\n",
	$inst;

print "<tr> <td><b>$text{'serv_nice'}</b></td>\n";
printf "<td><input type=radio name=nice_def value=1 %s> %s\n",
	$q->{'nice'} ? '' : 'checked', $text{'default'};
printf "<input type=radio name=nice_def value=0 %s>\n",
	$q->{'nice'} ? 'checked' : '';
printf "<input name=nice size=5 value='%s'></td>\n",
	$q->{'nice'}->[0];

$cps = uc($q->{'cps'}->[0]) eq 'UNLIMITED' ? '' : $q->{'cps'}->[0];
print "<td><b>$text{'serv_cps0'}</b></td>\n";
printf "<td><input type=radio name=cps_def value=1 %s> %s\n",
	$cps ? '' : 'checked', $text{'serv_cps_def'};
printf "<input type=radio name=cps_def value=0 %s>\n",
	$cps ? 'checked' : '';
printf "<input name=cps0 size=5 value='%s'> %s</td> </tr>\n",
	$cps;

print "<tr> <td colspan=2></td>\n";
print "<td><b>$text{'serv_cps1'}</b></td>\n";
printf "<td><input name=cps1 size=5 value='%s'> $text{'serv_sec'}</td> </tr>\n",
	$q->{'cps'}->[1];

print "</table></td></tr></table><p>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'serv_header3'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td valign=top><b>$text{'serv_from'}</b></td>\n";
printf "<td><input type=radio name=from_def value=1 %s> %s\n",
	$q->{'only_from'} ? '' : 'checked', $text{'serv_from_def'};
printf "<input type=radio name=from_def value=0 %s> %s<br>\n",
	$q->{'only_from'} ? 'checked' : '', $text{'serv_from_sel'};
print "<textarea name=from rows=4 cols=20>",
	join("\n", @{$q->{'only_from'}}),"</textarea></td>\n";

print "<td valign=top><b>$text{'serv_access'}</b></td>\n";
printf "<td><input type=radio name=access_def value=1 %s> %s\n",
	$q->{'no_access'} ? '' : 'checked', $text{'serv_access_def'};
printf "<input type=radio name=access_def value=0 %s> %s<br>\n",
	$q->{'no_access'} ? 'checked' : '', $text{'serv_access_sel'};
print "<textarea name=access rows=4 cols=20>",
	join("\n", @{$q->{'no_access'}}),"</textarea></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'serv_times'}</b></td>\n";
printf "<td colspan=3><input type=radio name=times_def value=1 %s> %s\n",
	$q->{'access_times'} ? '' : 'checked', $text{'serv_times_def'};
printf "<input type=radio name=times_def value=0 %s>\n",
	$q->{'access_times'} ? 'checked' : '';
printf "<input name=times size=40 value='%s'></td> </tr>\n",
	join(" ", @{$q->{'access_times'}});

print "</table></td></tr></table>\n";
print "<table width=100%><tr>\n";
if ($in{'new'}) {
	print "<td><input type=submit value='$text{'create'}'></td>\n";
	}
else {
	print "<td><input type=submit value='$text{'save'}'></td>\n";
	print "<td align=right><input type=submit name=delete ",
	      "value='$text{'delete'}'></td>\n";
	}
print "</tr></table></form>\n";

&ui_print_footer("", $text{'index_return'});

