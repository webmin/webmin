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

print &ui_form_start("save_rule.cgi", "post");
foreach $f ('table', 'idx', 'new', 'chain', 'before', 'after') {
	print &ui_hidden($f, $in{$f});
	}

# Display action section
print &ui_table_start($text{'edit_header1'}, "width=100%", 2);

print &ui_table_row(text{'edit_chain'},
	$text{"index_chain_".lc($rule->{'chain'})} ||
	&text('index_chain', "<tt>$rule->{'chain'}</tt>"));

# Rule comment
if ($config{'comment_mod'} || $rule->{'comment'}) {
	# Get comment from --comment option
	$cmt = $rule->{'comment'}->[1];
	}
else {
	# Get comment from # at end of line
	$cmt = $rule->{'cmt'};
	}
print &ui_table_row($text{'edit_cmt'},
	&ui_textbox("cmt", $cmt, 50));

# Action to take or chain to jump to
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
@grid = ( );
foreach $j (grep { &can_jump($_) } @jumps) {
	push(@grid, &ui_oneradio("jump", $j, $text{"index_jump_".lc($j)},
				 $rule->{'j'}->[1] eq $j));
	}
push(@grid, &ui_oneradio("jump", "*", $text{'edit_jump_other'}, !$found));
push(@grid, &ui_textbox("other", $found ? "" : $rule->{'j'}->[1], 12));
print &ui_table_row($text{'edit_jump'},
	&ui_grid_table(\@grid, 6, undef));

if (&indexof('REJECT', @jumps) >= 0 && &can_jump("REJECT")) {
	# Show input for REJECT icmp type
	if ($rule->{'j'}->[1] eq 'REJECT') {
		$rwith = $rule->{'reject-with'}->[1];
		}
	local @rtypes = ( "icmp-net-unreachable", "icmp-host-unreachable",
			  "icmp-port-unreachable", "icmp-proto-unreachable",
			  "icmp-net-prohibited", "icmp-host-prohibited",
			  "echo-reply", "tcp-reset" );
	priunt &ui_table_row($text{'edit_rwith'},
		&ui_radio("rwithdef", $rwith eq "" ? 1 : 0,
			  [ [ 1, $text{'default'} ],
			    [ 0, &text('edit_rwithtype',
			      &icmptype_input("rwithtype", $rwith, \@rtypes)) ],
			  ]));
	}

if (($table->{'name'} eq 'nat' && $rule->{'chain'} ne 'POSTROUTING') &&
     &can_jump("REDIRECT")) {
	# Show inputs for redirect host and port
	if ($rule->{'j'}->[1] eq 'REDIRECT') {
		($rtofrom, $rtoto) = split(/\-/, $rule->{'to-ports'}->[1]);
		}
	print &ui_table_row($text{'edit_rtoports'},
		&ui_radio("rtodef", rtofrom eq "" ? 1 : 0,
			  [ [ 1, $text{'default'} ],
			    [ 0, &text('edit_prange',
				       &ui_textbox("rtofrom", $rtofrom, 6),
				       &ui_textbox("rtoto", $rtoto, 6)) ] ]));
	}

if (($table->{'name'} eq 'nat' && $rule->{'chain'} ne 'PREROUTING' &&
     $rule->{'chain'} ne 'OUTPUT') &&
    &can_jump("MASQUERADE")) {
	# Show inputs for masquerading ports
	if ($rule->{'j'}->[1] eq 'MASQUERADE') {
		($mtofrom, $mtoto) = split(/\-/, $rule->{'to-ports'}->[1]);
		}
	print &ui_table_row($text{'edit_mtoports'},
		&ui_radio("mtodef", $mtofrom eq "" ? 1 : 0,
			  [ [ 1, $text{'edit_any'} ],
			    [ 0, &text('edit_prange',
				       &ui_textbox("mtofrom", $mtofrom, 6),
				       &ui_textbox("mtoto", $mtoto, 6)) ] ]));
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
	print &ui_table_row($text{'edit_dnat'},
		&ui_radio("dnatdef", $dipfrom eq "" ? 1 : 0,
			  [ [ 1, $text{'default'} ],
			    [ 0, &text('edit_dnatip',
				   &ui_textbox("dipfrom", $dipfrom, 15),
				   &ui_textbox("dipto", $dipto, 15))." ".
				 &text('edit_prange',
				   &ui_textbox("dpfrom", $dpfrom, 6),
				   &ui_textbox("dpto", $dpto, 6)) ] ]));
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
	print &ui_table_row($text{'edit_snat'},
		&ui_radio("snatdef", $sipfrom eq "" ? 1 : 0,
			  [ [ 1, $text{'default'} ],
			    [ 0, &text('edit_snatip',
				   &ui_textbox("sipfrom", $sipfrom, 15),
				   &ui_textbox("sipto", $sipto, 15))." ".
				 &text('edit_prange',
				   &ui_textbox("spfrom", $spfrom, 6),
				   &ui_textbox("spto", $spto, 6)) ] ]));
	}

print &ui_table_end();

# Display conditions section
print "$text{'edit_desc'}<br>\n";
print &ui_table_start($text{'edit_header2'}, "width=100%", 2);

# Packet source
print &ui_table_row($text{'edit_source'},
	&print_mode("source", $rule->{'s'})." ".
	&ui_textbox("source", $rule->{'s'}->[1], 40));

# Packet destination
print &ui_table_row($text{'edit_dest'},
	&print_mode("dest", $rule->{'d'})." ".
	&ui_textbox("dest", $rule->{'d'}->[1], 40));

# Incoming interface
print &ui_table_row($text{'edit_in'},
	&print_mode("in", $rule->{'i'})." ".
	&interface_choice("in", $rule->{'i'}->[1]));

# Outgoing interface
print &ui_table_row($text{'edit_out'},
	&print_mode("out", $rule->{'o'})." ".
	&interface_choice("out", $rule->{'o'}->[1]));

# Packet fragmentation
$f = !$rule->{'f'} ? 0 : $rule->{'f'}->[0] eq "!" ? 2 : 1;
print &ui_table_row($text{'edit_frag'},
	&ui_radio("frag", $f, [ [ 0, $text{'edit_ignore'} ],
				[ 1, $text{'edit_fragis'} ],
				[ 2, $text{'edit_fragnot'} ] ]));

# IP protocol
print &ui_table_row($text{'edit_proto'},
	&print_mode("proto", $rule->{'p'})." ".
	&protocol_input("proto", $rule->{'p'}->[1]));

print &ui_table_hr();

# Source port
print &ui_table_row($text{'edit_sport'},
	&print_mode("sport", $rule->{'sports'} || $rule->{'sport'})." ".
	&port_input("sport", $rule->{'sports'}->[1] || $rule->{'sport'}->[1]));

# Destination port
print &ui_table_row($text{'edit_dport'},
	&print_mode("dport", $rule->{'dports'} || $rule->{'dport'})." ".
	&port_input("dport", $rule->{'dports'}->[1] || $rule->{'dport'}->[1]));

# Source and destination ports
print &ui_table_row($text{'edit_ports'},
	&print_mode("ports", $rule->{'ports'})." ".
	&ui_textbox("ports", $rule->{'ports'}->[1], 30));

# TCP flags
print &ui_table_row($text{'edit_tcpflags'},
	"<table><tr><td>".&print_mode("tcpflags", $rule->{'tcp-flags'}).
	"</td> <td>".&text('edit_flags',
	    &tcpflag_input("tcpflags0", $rule->{'tcp-flags'}->[1]),
	    &tcpflag_input("tcpflags1", $rule->{'tcp-flags'}->[2])).
	"</td></tr></table>");

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
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'clone', $text{'edit_clone'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("index.cgi?table=$in{'table'}", $text{'index_return'});

# print_mode(name, &value, [yes-option, no-option], [no-no-option])
sub print_mode
{
local ($name, $value, $yes_opt, $no_opt, $no_no_opt);
local $m = !$value ? 0 :
	   $value->[0] eq "!" ? 2 : 1;
return &ui_select($name, $m,
	[ [ 0, "&lt;$text{'edit_ignore'}&gt;" ],
	  [ 1, $yes_opt || $text{'edit_is'} ],
	  !$no_no_opt || $m == 2 ? ( [ 2, $no_opt || $text{'edit_not'} ] )
				 : ( ) ]);
}

# port_input(name, value)
sub port_input
{
local ($name, $value) = @_;
local ($s, $e, $p);
if ($value =~ /^(\d*):(\d*)$/) {
	$s = $1; $e = $2;
	}
else {
	$p = $value || "";
	}
return &ui_radio($name."_type", defined($p) ? 0 : 1,
		 [ [ 0, $text{'edit_port0'}." ".
			&ui_textbox($name, $p, 15) ],
		   [ 1, &text('edit_port1',
			      &ui_textbox($name."_from", $s, 15),
			      &ui_textbox($name."_to", $e, 15)) ] ]);
}

# tcpflag_input(name, value)
sub tcpflag_input
{
local ($name, $value) = @_;
local %flags = map { $_, 1 } split(/,/, $value);
local $f;
local $rv = "<font size=-1>\n";
foreach $f ('SYN', 'ACK', 'FIN', 'RST', 'URG', 'PSH') {
	$rv .= &ui_checkbox($name, $f, "<tt>$f</tt>",
			    $flags{$f} || $flags{'ALL'})."\n";
	}
$rv .= "</font>\n";
return $rv;
}

# icmptype_input(name, value, [&types])
sub icmptype_input
{
local ($name, $value, $types) = @_;
local ($started, @types, $major, $minor);
$major = -1;
if ($types) {
	@types = @$types;
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
if (@types && $value !~ /^\d+$/ && $value !~ /^\d+\/\d+$/) {
	return &ui_select($name, $value, \@types);
	}
else {
	return &ui_textbox($name, $value, 6);
	}
}

# protocol_input(name, value)
sub protocol_input
{
local ($name, $value) = @_;
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
local @allprotos = &unique(@stdprotos, @otherprotos);
local $found = &indexof($value, @allprotos) >= 0;
return &ui_select($name, $found ? $value : "",
	[ (map { [ $_, uc($_) || "-------" ] } @allprotos),
	  [ '', $text{'edit_oifc'} ] ])." ".
       &ui_textbox($name."_other", $found ? undef : $value, 5);
}

# tos_input(name, value)
sub tos_input
{
local ($name, $value) = @_;
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
	return &ui_select($name, $value,
		[ map { [ $o->[0], "$o->[0] ($o->[1])" ] } @opts ]);
	}
else {
	return &ui_textbox($name, $value, 20);
	}
}

