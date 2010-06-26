#!/usr/local/bin/perl
# edit_rule.cgi
# Display the details of one firewall rule, or allow the adding of a new one

require './firewall-lib.pl';
&ReadParse();
@tables = &get_iptables_save();
$table = $tables[$in{'table'}];
&can_edit_table($table->{'name'}) || &error($text{'etable'});
if ($in{'clone'} ne '') {
	&ui_print_header(undef, $text{'edit_title3'}, "");
	%clone = %{$table->{'rules'}->[$in{'clone'}]};
	$rule = \%clone;
	}
elsif ($in{'new'}) {
	&ui_print_header(undef, $text{'edit_title1'}, "");
	$rule = { 'chain' => $in{'chain'},
		  'j' => &can_jump('DROP') ? 'DROP' : "" };
	}
else {
	&ui_print_header(undef, $text{'edit_title2'}, "");
	$rule = $table->{'rules'}->[$in{'idx'}];
	&can_jump($rule) || &error($text{'ejump'});
	}

print "<form action=save_rule.cgi method=post>\n";
foreach $f ('table', 'idx', 'new', 'chain', 'before', 'after') {
	print &ui_hidden($f, $in{$f});
	}

# Display action section
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_header1'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'edit_chain'}</b></td>\n";
print "<td>",$text{"index_chain_".lc($rule->{'chain'})} ||
	     &text('index_chain', "<tt>$rule->{'chain'}</tt>"),"</td> </tr>\n";

print "<tr> <td><b>$text{'edit_cmt'}</b></td>\n";
if ($config{'comment_mod'} || $rule->{'comment'}) {
	# Get comment from --comment option
	printf "<td><input name=cmt size=50 value='%s'></td> </tr>\n",
		&html_escape($rule->{'comment'}->[1]);
	}
else {
	# Get comment from # at end of line
	printf "<td><input name=cmt size=50 value='%s'></td> </tr>\n",
		&html_escape($rule->{'cmt'});
	}

print "<tr> <td valign=top><b>$text{'edit_jump'}</b></td> <td>\n";
if ($table->{'name'} eq 'nat') {
	@jumps = ( undef, 'ACCEPT', 'DROP' );
	if ($rule->{'chain'} eq 'POSTROUTING') {
		push(@jumps, 'MASQUERADE', 'SNAT');
		}
	elsif ($rule->{'chain'} eq 'PREROUTING' ||
	       $rule->{'chain'} eq 'OUTPUT') {
		push(@jumps, 'REDIRECT', 'DNAT');
		}
	else {
		push(@jumps, 'MASQUERADE', 'SNAT', 'REDIRECT', 'DNAT');
		}
	}
else {
	@jumps = ( undef, 'ACCEPT', 'DROP', 'REJECT', 'QUEUE', 'RETURN', 'LOG' );
	}
print "<table>\n";
$i = 0;
foreach $j (grep { &can_jump($_) } @jumps) {
	print "<tr>\n" if ($i%5 == 0);
	printf "<td><input type=radio name=jump value='%s' %s>&nbsp;%s</td>\n",
		$j, $rule->{'j'}->[1] eq $j ? "checked" : "",
		$text{"index_jump_".lc($j)};
	$found++ if ($rule->{'j'}->[1] eq $j);
	$i++;
	print "</tr>\n" if ($i%5 == 0);
	}
print "<td colspan=2>\n";
printf "<input type=radio name=jump value=* %s>&nbsp;%s&nbsp;",
	$found ? "" : "checked", $text{'edit_jump_other'};
printf "<input name=other size=12 value='%s'></td> </tr>\n",
	$found ? "" : $rule->{'j'}->[1];
print "</table></td></tr>\n";

if (&indexof('REJECT', @jumps) >= 0 && &can_jump("REJECT")) {
	# Show input for REJECT icmp type
	if ($rule->{'j'}->[1] eq 'REJECT') {
		$rwith = $rule->{'reject-with'}->[1];
		}
	print "<tr> <td><b>$text{'edit_rwith'}</b></td>\n";
	printf "<td><input type=radio name=rwithdef value=1 %s> %s\n",
		$rwith eq "" ? "checked" : "", $text{'default'};
	printf "<input type=radio name=rwithdef value=0 %s>\n",
		$rwith eq "" ? "" : "checked";
	local @rtypes = ( "icmp-net-unreachable", "icmp-host-unreachable",
			  "icmp-port-unreachable", "icmp-proto-unreachable",
			  "icmp-net-prohibited", "icmp-host-prohibited",
			  "echo-reply", "tcp-reset" );
	print &text('edit_rwithtype',
		    &icmptype_input("rwithtype", $rwith, \@rtypes)),
	            "</td> </tr>\n";
	}

if (($table->{'name'} eq 'nat' && $rule->{'chain'} ne 'POSTROUTING') &&
     &can_jump("REDIRECT")) {
	# Show inputs for redirect host and port
	if ($rule->{'j'}->[1] eq 'REDIRECT') {
		($rtofrom, $rtoto) = split(/\-/, $rule->{'to-ports'}->[1]);
		}
	print "<tr> <td><b>$text{'edit_rtoports'}</b></td>\n";
	printf "<td><input type=radio name=rtodef value=1 %s> %s\n",
		$rtofrom eq "" ? "checked" : "", $text{'default'};
	printf "<input type=radio name=rtodef value=0 %s>\n",
		$rtofrom eq "" ? "" : "checked";
	print &text('edit_prange',
		    "<input name=rtofrom size=6 value='$rtofrom'>",
		    "<input name=rtoto size=6 value='$rtoto'>"),"</td> </tr>\n";
	}

if (($table->{'name'} eq 'nat' && $rule->{'chain'} ne 'PREROUTING' &&
     $rule->{'chain'} ne 'OUTPUT') &&
    &can_jump("MASQUERADE")) {
	# Show inputs for masquerading ports
	if ($rule->{'j'}->[1] eq 'MASQUERADE') {
		($mtofrom, $mtoto) = split(/\-/, $rule->{'to-ports'}->[1]);
		}
	print "<tr> <td><b>$text{'edit_mtoports'}</b></td>\n";
	printf "<td><input type=radio name=mtodef value=1 %s> %s\n",
		$mtofrom eq "" ? "checked" : "", $text{'edit_any'};
	printf "<input type=radio name=mtodef value=0 %s>\n",
		$mtofrom eq "" ? "" : "checked";
	print &text('edit_prange',
		    "<input name=mtofrom size=6 value='$mtofrom'>",
		    "<input name=mtoto size=6 value='$mtoto'>"),"</td> </tr>\n";
	}

if (($table->{'name'} eq 'nat' && $rule->{'chain'} ne 'POSTROUTING') &&
    &can_jump("DNAT")) {
	if ($rule->{'j'}->[1] eq 'DNAT') {
		if ($rule->{'to-destination'}->[1] =~
		    /^([0-9\.]+)(\-([0-9\.]+))?(:(\d+)(\-(\d+))?)?$/) {
			$dipfrom = $1;
			$dipto = $3;
			$dpfrom = $5;
			$dpto = $7;
			}
		}
	print "<tr> <td><b>$text{'edit_dnat'}</b></td>\n";
	printf "<td><input type=radio name=dnatdef value=1 %s> %s\n",
		$dipfrom eq "" ? "checked" : "", $text{'default'};
	printf "<input type=radio name=dnatdef value=0 %s>\n",
		$dipfrom eq "" ? "" : "checked";
	print &text('edit_dnatip',
		    "<input name=dipfrom size=15 value='$dipfrom'>",
		    "<input name=dipto size=15 value='$dipto'>"),"\n";
	print &text('edit_prange',
		    "<input name=dpfrom size=6 value='$dpfrom'>",
		    "<input name=dpto size=6 value='$dpto'>"),"</td> </tr>\n";
	}

if (($table->{'name'} eq 'nat' && $rule->{'chain'} ne 'PREROUTING' &&
     $rule->{'chain'} ne 'OUTPUT') &&
    &can_jump("SNAT")) {
	if ($rule->{'j'}->[1] eq 'SNAT') {
		if ($rule->{'to-source'}->[1] =~
		    /^([0-9\.]+)(\-([0-9\.]+))?(:(\d+)(\-(\d+))?)?$/) {
			$sipfrom = $1;
			$sipto = $3;
			$spfrom = $5;
			$spto = $7;
			}
		}
	print "<tr> <td><b>$text{'edit_snat'}</b></td>\n";
	printf "<td><input type=radio name=snatdef value=1 %s> %s\n",
		$sipfrom eq "" ? "checked" : "", $text{'default'};
	printf "<input type=radio name=snatdef value=0 %s>\n",
		$sipfrom eq "" ? "" : "checked";
	print &text('edit_dnatip',
		    "<input name=sipfrom size=15 value='$sipfrom'>",
		    "<input name=sipto size=15 value='$sipto'>"),"\n";
	print &text('edit_prange',
		    "<input name=spfrom size=6 value='$spfrom'>",
		    "<input name=spto size=6 value='$spto'>"),"</td> </tr>\n";
	}

print "</table></td></tr></table><br>\n";

# Display conditions section
print "$text{'edit_desc'}<br>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_header2'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'edit_source'}</b></td>\n";
print "<td>",&print_mode("source", $rule->{'s'}),"\n";
printf "<input name=source size=30 value='%s'></td> </tr>\n",
	$rule->{'s'}->[1];

print "<tr> <td><b>$text{'edit_dest'}</b></td>\n";
print "<td>",&print_mode("dest", $rule->{'d'}),"\n";
printf "<input name=dest size=30 value='%s'></td> </tr>\n",
	$rule->{'d'}->[1];

print "<tr> <td><b>$text{'edit_in'}</b></td>\n";
print "<td>",&print_mode("in", $rule->{'i'}),"\n";
print &interface_choice("in", $rule->{'i'}->[1]),"</td> </tr>\n";

print "<tr> <td><b>$text{'edit_out'}</b></td>\n";
print "<td>",&print_mode("out", $rule->{'o'}),"\n";
print &interface_choice("out", $rule->{'o'}->[1]),"</td> </tr>\n";

$f = !$rule->{'f'} ? 0 : $rule->{'f'}->[0] eq "!" ? 2 : 1;
print "<tr> <td><b>$text{'edit_frag'}</b></td>\n";
printf "<td><input type=radio name=frag value=0 %s> %s\n",
	$f == 0 ? "checked" : "", $text{'edit_ignore'};
printf "<input type=radio name=frag value=1 %s> %s\n",
	$f == 1 ? "checked" : "", $text{'edit_fragis'};
printf "<input type=radio name=frag value=2 %s> %s</td> </tr>\n",
	$f == 2 ? "checked" : "", $text{'edit_fragnot'};

print "<tr> <td><b>$text{'edit_proto'}</b></td>\n";
print "<td>",&print_mode("proto", $rule->{'p'}),"\n";
print &protocol_input("proto", $rule->{'p'}->[1]),"</td> </tr>\n";

print "<tr> <td colspan=2><hr></td> </tr>\n";

print "<tr> <td><b>$text{'edit_sport'}</b></td>\n";
print "<td>",&print_mode("sport", $rule->{'sports'} || $rule->{'sport'}),"\n";
print &port_input("sport", $rule->{'sports'}->[1] || $rule->{'sport'}->[1]),
      "</td> </tr>\n";

print "<tr> <td><b>$text{'edit_dport'}</b></td>\n";
print "<td>",&print_mode("dport", $rule->{'dports'} || $rule->{'dport'}),"\n";
print &port_input("dport", $rule->{'dports'}->[1] || $rule->{'dport'}->[1]),
      "</td> </tr>\n";

print "<tr> <td><b>$text{'edit_ports'}</b></td>\n";
print "<td>",&print_mode("ports", $rule->{'ports'}),"\n";
printf "<input name=ports size=20 value='%s'></td> </tr>\n",
	$rule->{'ports'}->[1];

print "<tr> <td><b>$text{'edit_tcpflags'}</b></td>\n";
print "<td><table><tr><td>",&print_mode("tcpflags", $rule->{'tcp-flags'}),"\n";
print "</td> <td>",&text('edit_flags',
	    &tcpflag_input("tcpflags0", $rule->{'tcp-flags'}->[1]),
	    &tcpflag_input("tcpflags1", $rule->{'tcp-flags'}->[2])),
      "</td></tr></table> </td> </tr>\n";

print "<tr> <td><b>$text{'edit_tcpoption'}</b></td>\n";
print "<td>",&print_mode("tcpoption", $rule->{'tcp-option'}),"\n";
printf "<input name=tcpoption size=6 value='%s'></td> </tr>\n",
	$rule->{'tcp-option'}->[1];

print "<tr> <td colspan=2><hr></td> </tr>\n";

print "<tr> <td><b>$text{'edit_icmptype'}</b></td>\n";
print "<td>",&print_mode("icmptype", $rule->{'icmp-type'}),"\n";
print &icmptype_input("icmptype", $rule->{'icmp-type'}->[1]),"</td> </tr>\n";

print "<tr> <td><b>$text{'edit_mac'}</b></td>\n";
print "<td>",&print_mode("macsource", $rule->{'mac-source'}),"\n";
printf "<input name=macsource size=18 value='%s'></td> </tr>\n",
	$rule->{'mac-source'}->[1];

print "<tr> <td colspan=2><hr></td> </tr>\n";

print "<tr> <td><b>$text{'edit_limit'}</b></td>\n";
print "<td>",&print_mode("limit", $rule->{'limit'},
			 $text{'edit_below'}, $text{'edit_above'}, 1),"\n";
($n, $u) = $rule->{'limit'}->[1] =~ /^(\d+)\/(\S+)$/ ? ($1, $2) : ();
print "<input name=limit0 size=6 value='$n'>\n";
print "/ <select name=limit1>\n";
foreach $l ('second', 'minute', 'hour', 'day') {
	printf "<option value=%s %s>%s\n",
		$l, $u eq $l ? "selected" : "", $l;
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'edit_limitburst'}</b></td>\n";
print "<td>",&print_mode("limitburst", $rule->{'limit-burst'},
			 $text{'edit_below'}, $text{'edit_above'}, 1),"\n";
printf "<input name=limitburst size=6 value='%s'></td> </tr>\n",
	$rule->{'limit-burst'}->[1];

if ($rule->{'chain'} eq 'OUTPUT') {
	print "<tr> <td colspan=2><hr></td> </tr>\n";

	print "<tr> <td><b>$text{'edit_uidowner'}</b></td>\n";
	print "<td>",&print_mode("uidowner", $rule->{'uid-owner'}),"\n";
	printf "<input name=uidowner size=13 value='%s'> %s</td> </tr>\n",
		$rule->{'uid-owner'}->[1], &user_chooser_button("uidowner");

	print "<tr> <td><b>$text{'edit_gidowner'}</b></td>\n";
	print "<td>",&print_mode("gidowner", $rule->{'gid-owner'}),"\n";
	printf "<input name=gidowner size=13 value='%s'> %s</td> </tr>\n",
		$rule->{'gid-owner'}->[1], &group_chooser_button("gidowner");

	print "<tr> <td><b>$text{'edit_pidowner'}</b></td>\n";
	print "<td>",&print_mode("pidowner", $rule->{'pid-owner'}),"\n";
	printf "<input name=pidowner size=6 value='%s'></td> </tr>\n",
		$rule->{'pid-owner'}->[1];

	print "<tr> <td><b>$text{'edit_sidowner'}</b></td>\n";
	print "<td>",&print_mode("sidowner", $rule->{'sid-owner'}),"\n";
	printf "<input name=sidowner size=6 value='%s'></td> </tr>\n",
		$rule->{'sid-owner'}->[1];
	}

print "<tr> <td colspan=2><hr></td> </tr>\n";

# Connection states
print "<tr> <td valign=top><b>$text{'edit_state'}</b></td>\n";
print "<td><table cellpadding=0 cellspacing=0><tr><td valign=top>",
      &print_mode("state", $rule->{'state'}),"</td>\n";
print "<td>&nbsp;<select name=state multiple size=4>\n";
%states = map { $_,1 } split(/,/, $rule->{'state'}->[1]);
foreach $s ('NEW', 'ESTABLISHED', 'RELATED', 'INVALID', 'UNTRACKED') {
	printf "<option value=%s %s>%s (%s)\n",
		$s, $states{$s} ? "selected" : "",
		$text{"edit_state_".lc($s)}, $s;
	}
print "</select></td></tr></table></td> </tr>\n";

# Type of service
print "<tr> <td><b>$text{'edit_tos'}</b></td>\n";
print "<td>",&print_mode("tos", $rule->{'tos'}),"\n";
print &tos_input("tos", $rule->{'tos'}->[1]),"</td> </tr>\n";

print "<tr> <td colspan=2><hr></td> </tr>\n";

# Input physical device
print "<tr> <td><b>$text{'edit_physdevin'}</b></td>\n";
print "<td>",&print_mode("physdevin", $rule->{'physdev-in'}),"\n";
print &interface_choice("physdevin", $rule->{'physdev-in'}->[1]);
print "</td> </tr>\n";

# Output physical device
print "<tr> <td><b>$text{'edit_physdevout'}</b></td>\n";
print "<td>",&print_mode("physdevout", $rule->{'physdev-out'}),"\n";
print &interface_choice("physdevout", $rule->{'physdev-out'}->[1]);
print "</td> </tr>\n";

# Physdev match modes
print "<tr> <td><b>$text{'edit_physdevisin'}</b></td>\n";
print "<td>",&print_mode("physdevisin", $rule->{'physdev-is-in'},
			 $text{'yes'}, $text{'no'}),"</td> </tr>\n";
print "<tr> <td><b>$text{'edit_physdevisout'}</b></td>\n";
print "<td>",&print_mode("physdevisout", $rule->{'physdev-is-out'},
			 $text{'yes'}, $text{'no'}),"</td> </tr>\n";
print "<tr> <td><b>$text{'edit_physdevisbridged'}</b></td>\n";
print "<td>",&print_mode("physdevisbridged", $rule->{'physdev-is-bridged'},
			 $text{'yes'}, $text{'no'}),"</td> </tr>\n";

print "<tr> <td colspan=2><hr></td> </tr>\n";

# Show unknown modules
@mods = grep { !/^(tcp|udp|icmp|multiport|mac|limit|owner|state|tos|comment|physdev)$/ } map { $_->[1] } @{$rule->{'m'}};
print "<tr> <td><b>$text{'edit_mods'}</b></td>\n";
printf "<td colspan=3><input name=mods size=50 value='%s'></td> </tr>\n",
	join(" ", @mods);

# Show unknown parameters
$rule->{'args'} =~ s/^\s+//;
$rule->{'args'} =~ s/\s+$//;
print "<tr> <td><b>$text{'edit_args'}</b></td>\n";
printf "<td colspan=3><input name=args size=50 value='%s'></td> </tr>\n",
	$rule->{'args'};

print "</table></td></tr></table>\n";
print "<table width=100%><tr>\n";
if ($in{'new'}) {
	print "<td><input type=submit value='$text{'create'}'></td>\n";
	}
else {
	print "<td><input type=submit value='$text{'save'}'></td>\n";
	print "<td align=center><input type=submit name=clone ",
	      "value='$text{'edit_clone'}'></td>\n";
	print "<td align=right><input type=submit name=delete ",
	      "value='$text{'delete'}'></td>\n";
	}
print "</tr></table>\n";

&ui_print_footer("index.cgi?table=$in{'table'}", $text{'index_return'});

# print_mode(name, &value, [yes-option, no-option], [no-no-option])
sub print_mode
{
local $m = !$_[1] ? 0 :
	   $_[1]->[0] eq "!" ? 2 : 1;
local $rv = "<select name=$_[0]_mode>\n";
$rv .= sprintf "<option value=0 %s> &lt;%s&gt;\n",
	$m == 0 ? "selected" : "", $text{'edit_ignore'};
$rv .= sprintf "<option value=1 %s> %s\n",
	$m == 1 ? "selected" : "", $_[2] || $text{'edit_is'};
if (!$_[4] || $m == 2) {
	$rv .= sprintf "<option value=2 %s> %s\n",
		$m == 2 ? "selected" : "", $_[3] || $text{'edit_not'};
	}
$rv .= "</select>\n";
return $rv;
}

# port_input(name, value)
sub port_input
{
local ($s, $e, $p);
if ($_[1] =~ /^(\d*):(\d*)$/) {
	$s = $1; $e = $2;
	}
else {
	$p = $_[1] || "";
	}
local $rv = sprintf "<input type=radio name=$_[0]_type value=0 %s> %s\n",
		defined($p) ? "checked" : "", $text{'edit_port0'};
$rv .= "<input name=$_[0] size=15 value='$p'>\n";
$rv .= sprintf "<input type=radio name=$_[0]_type value=1 %s>\n",
		defined($p) ? "" : "checked";
$rv .= &text('edit_port1', "<input name=$_[0]_from size=5 value='$s'>",
			   "<input name=$_[0]_to size=5 value='$e'>");
return $rv;
}

# tcpflag_input(name, value)
sub tcpflag_input
{
local %flags = map { $_, 1 } split(/,/, $_[1]);
local $f;
local $rv = "<font size=-1>\n";
foreach $f ('SYN', 'ACK', 'FIN', 'RST', 'URG', 'PSH') {
	$rv .= sprintf "<input type=checkbox name=$_[0] value=%s %s> %s\n",
		$f, $flags{$f} || $flags{'ALL'} ? "checked" : "",
		"<tt>$f</tt>";
	}
$rv .= "</font>\n";
return $rv;
}

# icmptype_input(name, value, [&types])
sub icmptype_input
{
local ($started, @types, $major, $minor);
$major = -1;
if ($_[2]) {
	@types = @{$_[2]};
	}
else {
	open(IPTABLES, "iptables -p icmp -h 2>/dev/null |");
	while(<IPTABLES>) {
		if (/valid\s+icmp\s+types:/i) {
			$started = 1;
			}
		elsif (!/\S/) {
			$started = 0;
			}
		elsif ($started && /^\s*(\S+)/) {
			push(@types, $1);
			}
		}
	close(IPTABLES);
	}
if (@types && $_[1] !~ /^\d+$/ && $_[1] !~ /^\d+\/\d+$/) {
	local $rv = "<select name=$_[0]>\n";
	foreach $t (@types) {
		$rv .= sprintf "<option value=%s %s>%s\n",
				$t, $_[1] eq $t ? "selected" : "", $t;
		}
	$rv .= "</select>\n";
	return $rv;
	}
else {
	return "<input name=$_[0] size=6 value='$_[1]'>";
	}
}

# protocol_input(name, value)
sub protocol_input
{
local @stdprotos = ( 'tcp', 'udp', 'icmp', undef );
local @otherprotos;
open(PROTOS, "/etc/protocols");
while(<PROTOS>) {
	s/\r|\n//g;
	s/#.*$//;
	push(@otherprotos, $1) if (/^(\S+)\s+(\d+)/);
	}
close(PROTOS);
@otherprotos = sort { lc($a) cmp lc($b) } @otherprotos;
local $p;
local $rv = "<select name=$_[0]>\n";
local $found = $rule->{'p'}->[1] ? 0 : 1;
foreach $p (&unique(@stdprotos, @otherprotos)) {
	$rv .= sprintf "<option value='%s' %s>%s\n",
			$p, $rule->{'p'}->[1] eq $p && $p ? "selected" : "",
			uc($p) || "-------";
	$found++ if ($rule->{'p'}->[1] eq $p && $p);
	}
$rv .= sprintf "<option value='%s' %s>%s\n",
		'', !$found ? "selected" : "", $text{'edit_oifc'};
$rv .= "</select>\n";
$rv .= &ui_textbox($_[0]."_other", $found ? undef : $rule->{'p'}->[1], 5);
return $rv;
}

# tos_input(name, value)
sub tos_input
{
local ($started, @opts);
open(IPTABLES, "iptables -m tos -h 2>/dev/null |");
while(<IPTABLES>) {
	if (/TOS.*options:/i) {
		$started = 1;
		}
	elsif ($started && /^\s+(\S+)\s+(\d+)\s+\((0x[0-9a-f]+)\)/i) {
		push(@opts, [ $1, $3 ]);
		}
	}
close(IPTABLES);
if (@opts) {
	local $rv = "<select name=$_[0]>\n";
	foreach $o (@opts) {
		$rv .= sprintf "<option value=%s %s>%s\n",
			$o->[0], $o->[0] eq $_[1] ? "selected" : "",
			"$o->[0] ($o->[1])";
		}
	$rv .= "</select>\n";
	return $rv;
	}
else {
	return "<input name=$_[0] size=20 value='$_[1]'>\n";
	}
}

