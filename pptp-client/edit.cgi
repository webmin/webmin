#!/usr/local/bin/perl
# edit.cgi
# Display a form for editing tunnel details

require './pptp-client-lib.pl';
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'edit_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'edit_title2'}, "");
	($tunnel) = grep { $_->{'name'} eq $in{'tunnel'} } &list_tunnels();
	&parse_comments($tunnel);
	$login = &find("name", $tunnel->{'opts'});
	$sn = $login ? $login->{'value'} : &get_system_hostname(1);
	@secs = &list_secrets();
	($sec) = grep { $_->{'client'} eq $sn } @secs;
	}

print "<form action=save.cgi method=post>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=old value='$in{'tunnel'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'edit_name'}</b></td>\n";
printf "<td><input name=tunnel size=30 value='%s'></td>\n",
	$tunnel->{'name'};

print "<td><b>$text{'edit_server'}</b></td>\n";
printf "<td><input name=server size=20 value='%s'></td> </tr>\n",
	$tunnel->{'server'};

print "<tr> <td><b>$text{'edit_login'}</b></td>\n";
printf "<td nowrap><input type=radio name=login_def value=1 %s> %s\n",
	$login ? "" : "checked", $text{'edit_same'};
printf "<input type=radio name=login_def value=0 %s>\n",
	$login ? "checked" : "";
printf "<input name=login size=15 value='%s'></td>\n",
	$login->{'value'};

print "<td><b>$text{'edit_pass'}</b></td>\n";
printf "<td><input name=spass type=password value='%s'></td> </tr>\n",
	$sec->{'secret'};

$remote = &find("remotename", $tunnel->{'opts'});
print "<tr> <td><b>$text{'edit_remote'}</b></td>\n";
printf "<td nowrap><input type=radio name=remote_def value=1 %s> %s\n",
	$remote ? "" : "checked", $text{'edit_auto'};
printf "<input type=radio name=remote_def value=0 %s>\n",
	$remote ? "checked" : "";
printf "<input name=remote size=15 value='%s'></td>\n",
	$remote->{'value'};

print "</tr>\n";

# Show PPP include file
$file = &find("file", $tunnel->{'opts'});
$fmode = $in{'new'} ? 1 : !$file ? 0 :
	 $file->{'value'} eq $config{'pptp_options'} ? 1 : 2;
print "<tr> <td><b>$text{'edit_file'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=file_def value=0 %s> %s\n",
	$fmode == 0 ? "checked" : "", $text{'edit_none'};
printf "<input type=radio name=file_def value=1 %s> %s\n",
	$fmode == 1 ? "checked" : "", $text{'edit_global'};
printf "<input type=radio name=file_def value=2 %s> %s\n",
	$fmode == 2 ? "checked" : "", $text{'edit_ofile'};
printf "<input name=file size=30 value='%s'> %s</td> </tr>\n",
	$fmode == 2 ? $file->{'value'} : "", &file_chooser_button("file");

print "<tr> <td colspan=4><hr></td> </tr>\n";

# Parse all route comments
foreach $r (@{$tunnel->{'routes'}}) {
	if ($r =~ /^\s*add\s+-net\s+(\S+)\s+netmask\s+(\S+)\s+gw\s+(\S+)\s*$/) {
		# Net route to specific gateway
		push(@kroutes, [ 1, $1, $2, $3 ]);
		}
	elsif ($r =~ /^\s*add\s+-net\s+(\S+)\s+gw\s+(\S+)\s+netmask\s+(\S+)\s*$/) {
		# Net route to specific gateway
		push(@kroutes, [ 1, $1, $3, $2 ]);
		}
	elsif ($r =~ /^\s*add\s+-net\s+(\S+)\s+netmask\s+(\S+)\s+dev\s+(TUNNEL_DEV)\s*$/) {
		# Net route to other end
		push(@kroutes, [ 1, $1, $2, 'GW' ]);
		}
	elsif ($r =~ /^\s*add\s+-net\s+(\S+)\s+dev\s+(TUNNEL_DEV)\s+netmask\s+(\S+)\s*$/) {
		# Net route to other end
		push(@kroutes, [ 1, $1, $3, 'GW' ]);
		}

	elsif ($r =~ /^\s*add\s+-host\s+(\S+)\s+gw\s+(\S+)\s*$/) {
		# Host route to specific gateway
		push(@kroutes, [ 2, $1, undef, $2 ]);
		}
	elsif ($r =~ /^\s*add\s+-host\s+(\S+)\s+dev\s+(TUNNEL_DEV)\s*$/) {
		# Host route to specific gateway
		push(@kroutes, [ 2, $1, undef, 'GW' ]);
		}

	elsif ($r =~ /^\s*add\s+default\s+gw\s+(\S+)\s*$/) {
		# Default route to specific gateway
		$adddef = $1;
		}
	elsif ($r =~ /^\s*add\s+default\s+dev\s+(TUNNEL_DEV)\s*$/) {
		# Default route to other end
		$adddef = 'GW';
		}

	elsif ($r =~ /^\s*delete\s+default\s*$/) {
		# Deleting old default route
		$deldef = 1;
		}
	else {
		push(@uroutes, $r);
		}
	}

# Show default route options
print "<tr> <td><b>$text{'edit_adddef'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=adddef value=1 %s> %s\n",
	$adddef eq "GW" ? "checked" : "", $text{'edit_def1'};
printf "<input type=radio name=adddef value=2 %s> %s\n",
	$adddef && $adddef ne "GW" ? "checked" : "", $text{'edit_def2'};
printf "<input name=def size=15 value='%s'>\n",
	$adddef eq "GW" ? "" : $adddef;
printf "<input type=radio name=adddef value=0 %s> %s\n",
	$adddef ? "" : "checked", $text{'no'};
print "</td> </tr>\n";

print "<tr> <td><b>$text{'edit_deldef'}</b></td>\n";
printf "<td><input type=radio name=deldef value=1 %s> %s\n",
	$deldef ? "checked" : "", $text{'yes'};
printf "<input type=radio name=deldef value=0 %s> %s</td> </tr>\n",
	$deldef ? "" : "checked", $text{'no'};

# Show editable routes
print "<tr> <td valign=top><b>$text{'edit_routes'}</b></td>\n";
print "<td colspan=3><table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_type'}</b></td> ",
      "<td><b>$text{'edit_net'}</b></td> ",
      "<td><b>$text{'edit_mask'}</b></td> ",
      "<td><b>$text{'edit_gw'}</b></td> </tr>\n";
$i = 0;
foreach $r (@kroutes, [ 0, undef, undef, 'GW' ]) {
	print "<tr $cb>\n";
	print "<td><select name=type_$i>\n";
	foreach $o (0 .. 2) {
		printf "<option value=%d %s>%s</option>\n",
			$o, $r->[0] == $o ? "selected" : "",
			$text{'edit_type'.$o};
		}
	print "</select></td>\n";
	print "<td><input name=net_$i size=15 value='$r->[1]'></td>\n";
	print "<td><input name=mask_$i size=15 value='$r->[2]'></td>\n";
	printf "<td nowrap><input type=radio name=gw_def_$i value=1 %s> %s\n",
		$r->[3] eq 'GW' ? "checked" : "", $text{'edit_gw_def'};
	printf "<input type=radio name=gw_def_$i value=0 %s>\n",
		$r->[3] eq 'GW' ? "" : "checked";
	printf "<input name=gw_$i size=15 value='%s'></td>\n",
		$r->[3] eq 'GW' ? "" : $r->[3];
	print "</tr>\n";
	$i++;
	}
print "</table></td> </tr>\n";

# Show other route commands
print "<tr> <td valign=top><b>$text{'edit_unknown'}</b></td>\n";
print "<td colspan=3><textarea name=unknown rows=3 cols=60>",
	join("\n", @uroutes),"</textarea></td> </tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

# Show MPPE options
print "<tr> <td colspan=4 align=center>$text{'opts_msdesc'}</td> </tr>\n";
&mppe_options_form($tunnel->{'opts'});

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
print "</tr></table>\n";

&ui_print_footer("", $text{'index_return'});

