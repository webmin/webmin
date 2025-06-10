#!/usr/local/bin/perl
# edit_rule.cgi
# Display the details of one firewall rule, or allow the adding of a new one

require './firewall-lib.pl';
&ReadParse();
if (&get_ipvx_version() == 6) {
	require './firewall6-lib.pl';
	}
else {
	require './firewall4-lib.pl';
	}
@tables = &get_iptables_save();
$table = $tables[$in{'table'}];
&can_edit_table($table->{'name'}) || &error($text{'etable'});
if ($in{'clone'} ne '') {
	&ui_print_header($text{"index_title_v${ipvx}"}, $text{'edit_title3'}, "");
	%clone = %{$table->{'rules'}->[$in{'clone'}]};
	$rule = \%clone;
	}
elsif ($in{'new'}) {
	&ui_print_header($text{"index_title_v${ipvx}"}, $text{'edit_title1'}, "");
	$rule = { 'chain' => $in{'chain'},
		  'j' => &can_jump('DROP') ? 'DROP' : "" };
	}
else {
	&ui_print_header($text{"index_title_v${ipvx}"}, $text{'edit_title2'}, "");
	$rule = $table->{'rules'}->[$in{'idx'}];
	&can_jump($rule) || &error($text{'ejump'});
	}

print &ui_form_start("save_rule${ipvx}.cgi", "post");
print &ui_hidden("version", ${ipvx_arg});
foreach $f ('table', 'idx', 'new', 'chain', 'before', 'after') {
	print &ui_hidden($f, $in{$f});
	}

# Display action section
print &ui_table_start($text{'edit_header1'}, "width=100%", 2);

print &ui_table_row($text{'edit_chain'},
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
$found = 0;
foreach $j (grep { &can_jump($_) } @jumps) {
	push(@grid, &ui_oneradio("jump", $j, $text{"index_jump_".lc($j)},
				 $rule->{'j'}->[1] eq $j));
	$found++ if ($rule->{'j'}->[1] eq $j);
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
	print &ui_table_row($text{'edit_rwith'},
		&ui_radio("rwithdef", $rwith eq "" ? 1 : 0,
			  [ [ 1, $text{'default'} ],
			    [ 0, &text('edit_rwithtype',
			      &icmptype_input("rwithtype", $rwith, \@ipvx_rtypes)) ],
			  ]));
	}

if (($table->{'name'} eq 'nat' && $rule->{'chain'} ne 'POSTROUTING') &&
     &can_jump("REDIRECT")) {
	# Show inputs for redirect host and port
	if ($rule->{'j'}->[1] eq 'REDIRECT') {
		($rtofrom, $rtoto) = split(/\-/, $rule->{'to-ports'}->[1]);
		}
	print &ui_table_row($text{'edit_rtoports'},
		&ui_radio("rtodef", $rtofrom eq "" ? 1 : 0,
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
		    /$ipvx_todestpattern/) {
			$dipfrom = $1;
			$dipto = $3;
			$dpfrom = $5;
			$dpto = $7;
			}
		elsif ($rule->{'to-destination'}->[1] =~ /^(:(\d+)(\-(\d+))?)?$/) {
			$dipfrom = "";
			$dipto = "";
			$dpfrom = $2;
			$dpto = $4;
			}
		elsif (&check_ipvx_ipaddress($rule->{'to-destination'}->[1])) {
			$dipfrom = $rule->{'to-destination'}->[1];
			$dipto = "";
			$dpfrom = "";
			$dpto = "";
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
		    /^([0-9\.]+)?(\-([0-9\.]+))?(:(\d+)(\-(\d+))?)?$/) {
			$sipfrom = $1;
			$sipto = $3;
			$spfrom = $5;
			$spto = $7;
			}
		}
	print &ui_table_row($text{'edit_snat'},
		&ui_radio("snatdef", $sipfrom eq "" ? 1 : 0,
			  [ [ 1, $text{'default'} ],
			    [ 0, &text('edit_dnatip',
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
	&ui_grid_table([
		&print_mode("source", $rule->{'s'}),
		&ui_textarea("source", join(" ", split(/,/, $rule->{'s'}->[1])),
			     4, 60),
		], 2));

# Packet destination
print &ui_table_row($text{'edit_dest'},
	&ui_grid_table([
		&print_mode("dest", $rule->{'d'}),
		&ui_textarea("dest", join(" ", split(/,/, $rule->{'d'}->[1])),
			     4, 60),
		], 2));

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

# TCP options
print &ui_table_row($text{'edit_tcpoption'},
	&print_mode("tcpoption", $rule->{'tcp-option'})." ".
	&ui_textbox("tcpoption", $rule->{'tcp-option'}->[1], 6));

print &ui_table_hr();

# ICMP packet type
print &ui_table_row($text{'edit_icmptype'},
	&print_mode("icmptype", $rule->{"icmp${ipvx_icmp}-type"})." ".
	&icmptype_input("icmptype", $rule->{"icmp${ipvx_icmp}-type"}->[1]));

# MAC address
print &ui_table_row($text{'edit_mac'},
	&print_mode("macsource", $rule->{'mac-source'})." ".
	&ui_textbox("macsource", $rule->{'mac-source'}->[1], 18));

print &ui_table_hr();

# Packet flow limit
($n, $u) = $rule->{'limit'} &&
	   $rule->{'limit'}->[1] =~ /^(\d+)\/(\S+)$/ ? ($1, $2) : ();
print &ui_table_row($text{'edit_limit'},
	&print_mode("limit", $rule->{'limit'},
		    $text{'edit_below'}, $text{'edit_above'}, 1)." ".
	&ui_textbox("limit0", $n, 6)." / ".
	&ui_select("limit1", $u, ['second', 'minute', 'hour', 'day']));

# Packet burst rate
print &ui_table_row($text{'edit_limitburst'},
	&print_mode("limitburst", $rule->{'limit-burst'},
		    $text{'edit_below'}, $text{'edit_above'}, 1)." ".
	&ui_textbox("limitburst", $rule->{'limit-burst'}->[1], 6));

if ($rule->{'chain'} eq 'OUTPUT') {
	print &ui_table_hr();

	# Sending UID
	print &ui_table_row($text{'edit_uidowner'},
		&print_mode("uidowner", $rule->{'uid-owner'})." ".
		&ui_user_textbox("uidowner", $rule->{'uid-owner'}->[1]));

	# Sending GID
	print &ui_table_row($text{'edit_gidowner'},
		&print_mode("gidowner", $rule->{'gid-owner'})." ".
		&ui_group_textbox("gidowner", $rule->{'gid-owner'}->[1]));

	# Sending process ID
	print &ui_table_row($text{'edit_pidowner'},
		&print_mode("pidowner", $rule->{'pid-owner'})." ".
		&ui_textbox("pidowner", $rule->{'pid-owner'}->[1], 6));

	# Sending process group
	print &ui_table_row($text{'edit_sidowner'},
		&print_mode("sidowner", $rule->{'sid-owner'})." ".
		&ui_textbox("sidowner", $rule->{'sid-owner'}->[1], 6));
	}

print &ui_table_hr();

# Connection states
my $sd = &supports_conntrack() ? "ctstate" : "state";
print &ui_table_row($text{'edit_state'},
	"<table cellpadding=0 cellspacing=0><tr><td valign=top>".
	&print_mode($sd, $rule->{$sd})."</td>\n".
	"<td>&nbsp;".
	&ui_select($sd, [ split(/,/, $rule->{$sd}->[1]) ],
	   [ map { [ $_, $text{"edit_state_".lc($_)} ] }
		 ('NEW', 'ESTABLISHED', 'RELATED', 'INVALID', 'UNTRACKED',
		  $sd eq "state" ? ( ) : ('SNAT', 'DNAT')) ], 5, 1).
	"</td></tr></table>");

# Type of service
print &ui_table_row($text{'edit_tos'},
	&print_mode("tos", $rule->{'tos'})." ".
	&tos_input("tos", $rule->{'tos'}->[1]));

print &ui_table_hr();

# Input physical device
print &ui_table_row($text{'edit_physdevin'},
	&print_mode("physdevin", $rule->{'physdev-in'})." ".
	&interface_choice("physdevin", $rule->{'physdev-in'}->[1]));

# Output physical device
print &ui_table_row($text{'edit_physdevout'},
	&print_mode("physdevout", $rule->{'physdev-out'})." ".
	&interface_choice("physdevout", $rule->{'physdev-out'}->[1]));

# Physdev match modes
print &ui_table_row($text{'edit_physdevisin'},
	&print_mode("physdevisin", $rule->{'physdev-is-in'},
		    $text{'yes'}, $text{'no'}));
print &ui_table_row($text{'edit_physdevisout'},
	&print_mode("physdevisout", $rule->{'physdev-is-out'},
		    $text{'yes'}, $text{'no'}));
print &ui_table_row($text{'edit_physdevisbridged'},
	&print_mode("physdevisbridged", $rule->{'physdev-is-bridged'},
		    $text{'yes'}, $text{'no'}));

# IPset to match
print &ui_table_row($text{'edit_matchset'},
	&print_mode("matchset", $rule->{'match-set'})." ".
	&ui_select("matchset", $rule->{'match-set'}->[1],
		   [ map { $_->{'Name'} } &get_ipsets_active() ])." ".
	&ui_select("matchset2", $rule->{'match-set'}->[2],
		   [ [ "src", $text{'edit_matchsetsrc'} ],
		     [ "dst", $text{'edit_matchsetdst'} ] ], 1, 0,
		   $rule->{'match-set'}->[2] ? 1 : 0));

print &ui_table_hr();

# Show unknown modules
@mods = grep { !/^(tcp|udp|icmp${ipvx_icmp}|multiport|mac|limit|owner|state|conntrack|tos|comment|physdev|set)$/ } map { $_->[1] } @{$rule->{'m'}};
print &ui_table_row($text{'edit_mods'},
	&ui_textbox("mods", join(" ", @mods), 60));

# Show unknown parameters
$rule->{'args'} =~ s/^\s+//;
$rule->{'args'} =~ s/\s+$//;
print &ui_table_row($text{'edit_args'},
	&ui_textbox("args", $rule->{'args'}, 60));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'clone', $text{'edit_clone'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("index.cgi?version=${ipvx_arg}", $text{'index_return'});

# print_mode(name, &value, [yes-option, no-option], [no-no-option])
sub print_mode
{
local ($name, $value, $yes_opt, $no_opt, $no_no_opt) = @_;
local $m = !$value ? 0 :
	   $value->[0] eq "!" ? 2 : 1;
return &ui_select($name."_mode", $m,
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
			      &ui_textbox($name."_from", $s, 6),
			      &ui_textbox($name."_to", $e, 6)) ] ]);
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
	open(IPTABLES, "ip${ipvx}tables -p icmp${ipvx_icmp} -h 2>/dev/null |");
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
local @stdprotos = ( 'tcp', 'udp', "icmp${ipvx_icmp}", undef );
$value ||= "tcp";
local @otherprotos;
open(PROTOS, "</etc/protocols");
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
open(IPTABLES, "ip${ipvx}tables -m tos -h 2>/dev/null |");
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

