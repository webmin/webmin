#!/usr/local/bin/perl
# Display a form for editing or creating a firewall rule

require './ipfw-lib.pl';
&ReadParse();
$rules = &get_config();

if ($in{'delsel'}) {
	# Special case - deleting selected rules
	%nums = map { $_, 1 } split(/\0/, $in{'d'});
	@$rules = grep { !$nums{$_->{'num'}} } @$rules;
	&lock_file($ipfw_file);
	&save_config($rules);
	&unlock_file($ipfw_file);
	&webmin_log("delsel", undef, undef,
		    { 'count' => scalar(keys %nums) });
	&redirect("");
	exit;
	}

if ($in{'new'}) {
	&ui_print_header(undef, $text{'edit_title1'}, "");
	$rule = { 'action' => 'allow',
		  'from' => 'any',
		  'to' => 'any' };
	}
else {
	$rule = $rules->[$in{'idx'}];
	&ui_print_header(undef, &text('edit_title2', $rule->{'num'}), "");
	}

print &ui_form_start("save_rule.cgi", "post");
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_hidden("idx", $in{'idx'}),"\n";
print &ui_hidden("before", $in{'before'}),"\n";
print &ui_hidden("after", $in{'after'}),"\n";
@tds = ( "width=20%", undef );

print &ui_table_start($text{'edit_header1'}, "width=100%", 2);

# Comment
print &ui_table_row($text{'edit_cmt'},
		    $rule->{'cmt'} =~ /\n/ ? 
			&ui_textarea("cmt", $rule->{'cmt'}, 3, 50) :
			&ui_textbox("cmt", $rule->{'cmt'}, 50),
		    undef, \@tds);

# Number for new rules
if ($in{'new'} && !$in{'before'} && !$in{'after'}) {
	print &ui_table_row($text{'edit_num'},
		&ui_opt_textbox("num", undef, 6, $text{'default'}));
	}

# Rule action and argument
$ra = &real_action($rule->{'action'});
push(@action, $ra) if ($ra && &indexof($ra, @actions) < 0);
$acts = "<table cellpadding=1 cellspacing=1>\n";
$i = 0;
foreach $a (@actions) {
	$acts .= "<tr>\n" if ($i%2 == 0);
	$acts .= "<td nowrap>";
	local $ma = $rule->{'action'} eq $a;
	$acts .= &ui_oneradio("action", $a,
			$text{"laction_".$a} || $text{"action_".$a} || uc($a),
			$ma);
	if ($a eq "skipto") {
		$acts .= &ui_textbox("action_skipto",
				     $ma ? $rule->{'aarg'} : "", 8);
		}
	elsif ($a eq "fwd") {
		local ($ip, $port) = split(/,/, $rule->{'aarg'});
		$acts .= &ui_textbox("action_fwdip", $ma ? $ip : "", 15).":".
			 &ui_textbox("action_fwdport", $ma ? $port : "", 5);
		}
	elsif ($a eq "divert" || $a eq "pipe" || $a eq "queue" || $a eq "tee") {
		$acts .= &ui_textbox("action_port",
				     $ma ? $rule->{'aarg'} : "", 5);
		}
	elsif ($a eq "unreach") {
		$acts .= &ui_select("action_unreach", $ma ? $rule->{'aarg'} :"",
				    [ map { [ $_, $_ ] } @unreaches ]);
		}
	$acts .= "</td>";
	$acts .= "</tr>\n" if ($i++%2 == 1);
	}
$acts .= "</table>\n";
print &ui_table_row($text{'edit_action'}, $acts,
		    undef, \@tds);

# Logging field
print &ui_table_row($text{'edit_log'},
		   &ui_oneradio("log", 0, $text{'no'},
				!$rule->{'log'})." ".
		   &ui_oneradio("log", 1,
				&text('edit_logyes',
			          &ui_textbox("logamount",
						$rule->{'logamount'}, 5)),
				$rule->{'log'}));

# State-keeping rule
print &ui_table_row($text{'edit_keep-state'},
		    &yes_no_ignored_input("keep-state"), 1, \@tds);

print &ui_table_end();
print "<p>\n";

# Condition section
print "$text{'edit_desc'}<br>\n";
print &ui_table_start($text{'edit_header3'}, "width=100%", 4);

# Protocol field
if (ref($rule->{'proto'})) {
	# Multiple or-block values!
	print &ui_table_row($text{'edit_proto'},
			    &orblock_input("proto", $rule->{'proto'}));
	}
else {
	local @protos = &list_protocols();
	$rule->{'proto'} = "all" if ($rule->{'proto'} eq "ip");
	print &ui_table_row($text{'edit_proto'},
			    &ui_select("proto", $rule->{'proto'},
				       [ [ "all", $text{'edit_any'} ],
					 map { [ $_, uc($_) ] } @protos ]),
			    undef, \@tds);
	}

# Incoming / outgoing
$iomode = $rule->{'in'} || $rule->{'out'} && $rule->{'out_not'} ? 1 :
	  $rule->{'out'} || $rule->{'in'} && $rule->{'in_not'} ? 2 : 0;
print &ui_table_row($text{'edit_inout'},
		    &ui_select("inout", $iomode,
			      [ [ 0, "<$text{'edit_ignored'}>" ],
				[ 1, $text{'edit_inout1'} ],
				[ 2, $text{'edit_inout2'} ] ]), 1, \@tds);

# Via interface
print &ui_table_row($text{'edit_via'},
		    &interface_choice("via", $rule->{'via'}), 1, \@tds);

print &ui_table_end();
print "<p>\n";

# Source and destination sections
foreach $s ("from", "to") {
	print &ui_table_start($text{'edit_header'.$s}, "width=100%", 2);

	# IP address
	if (ref($rule->{$s})) {
		print &ui_table_row($text{'edit_'.$s},
				    &orblock_input($s, $rule->{$s}));
		}
	else {
		local $mode = $rule->{$s} eq "any" ? 0 :
			      $rule->{$s} eq "me" ? 1 : 2;
		print &ui_table_row($text{'edit_'.$s},
		      &ui_oneradio($s."_mode", 0, $text{'edit_sany'},
				   $mode == 0)."<br>".
		      &ui_oneradio($s."_mode", 1, $text{'edit_sme'},
				   $mode == 1)."<br>".
		      &ui_oneradio($s."_mode", 2, $text{'edit_saddr'},
				   $mode == 2)." ".
		      &ui_textbox($s, $mode == 2 ? $rule->{$s} : "", 40),
		      undef, \@tds);
		print &ui_table_row("",
		      &ui_checkbox($s."_not", 1, $text{'edit_snot'},
				   $rule->{$s."_not"}),
		      undef, \@tds);
		}
	#print &ui_table_hr();

	# Ports within IPs
	if (ref($rule->{$s."_ports"})) {
		print &ui_table_row($text{'edit_port'.$s},
		    &orblock_input($s."_ports", $rule->{$s."_ports"}));
		}
	else {
		local $mode = defined($rule->{$s."_ports"}) ? 1 : 0;
		print &ui_table_row($text{'edit_port'.$s},
		      &ui_oneradio($s."_ports_mode", 0, $text{'edit_pany'},
				   $mode == 0)."<br>".
		      &ui_oneradio($s."_ports_mode", 1, $text{'edit_ports'},
				   $mode == 1)." ".
		      &ui_textbox($s."_ports", $mode == 1 ? $rule->{$s."_ports"}
						 : "", 40),
		      undef, \@tds);
		if ($ipfw_version >= 2) {
			print &ui_table_row("",
			      &ui_checkbox($s."_ports_not", 1, $text{'edit_pnot'},
					   $rule->{$s."_ports_not"}),
			      undef, \@tds);
			}
		}

	# Received interface
	local $rs = $s eq "from" ? "recv" : "xmit";
	print &ui_table_row($text{'edit_'.$rs},
			    &interface_choice($rs, $rule->{$rs}), 1, \@tds);

	print &ui_table_end();
	print "<p>\n";
	}

# Options section
@tds = ( "", "nowrap" );
# XXX or-block support
print &ui_table_start($text{'edit_header2'}, "width=100%", 4);

# Established traffic
print &ui_table_row($text{'edit_established'},
		    &yes_no_ignored_input("established"), 1, \@tds);

# TCP setup packets
print &ui_table_row($text{'edit_setup'},
		    &yes_no_ignored_input("setup"), 1, \@tds);

# Bridged packets
print &ui_table_row($text{'edit_bridged'},
		    &yes_no_ignored_input("bridged"), 1, \@tds);

# Fragmented packets
print &ui_table_row($text{'edit_frag'},
		    &yes_no_ignored_input("frag"), 1, \@tds);

# MAC addresses (if supported)
if ($ipfw_version >= 2) {
	local ($md, $ms) = $rule->{'mac'} ? @{$rule->{'mac'}} : ( "any", "any" );
	print &ui_table_row($text{'edit_mac1'},
		    &ui_radio("mac1_def", $ms eq "any" ? 1 : 0,
			      [ [ 1, $text{'edit_ignored'} ],
				[ 0, $text{'edit_macaddr'} ] ] )." ".
		    &ui_textbox("mac1", $ms eq "any" ? "" : $ms, 20), 3, \@tds);
	print &ui_table_row($text{'edit_mac2'},
		    &ui_radio("mac2_def", $md eq "any" ? 1 : 0,
			      [ [ 1, $text{'edit_ignored'} ],
				[ 0, $text{'edit_macaddr'} ] ] )." ".
		    &ui_textbox("mac2", $md eq "any" ? "" : $md, 20), 3, \@tds);
	}

# UID and GID
if (defined($rule->{'uid'})) {
	$user = getpwuid($rule->{'uid'});
	$user = "#".$rule->{'uid'} if (!defined($user));
	}
print &ui_table_row($text{'edit_uid'},
		    &ui_radio("uid_def", $user ? 0 : 1,
			      [ [ 1, $text{'edit_ignored'} ],
				[ 0, $text{'edit_user'} ] ] )." ".
		    &ui_user_textbox("uid", $user), 3, \@tds);
if (defined($rule->{'gid'})) {
	$group = getgrgid($rule->{'gid'});
	$group = "#".$rule->{'gid'} if (!defined($group));
	}
print &ui_table_row($text{'edit_gid'},
		    &ui_radio("gid_def", $group ? 0 : 1,
			      [ [ 1, $text{'edit_ignored'} ],
				[ 0, $text{'edit_group'} ] ] )." ".
		    &ui_group_textbox("gid", $group), 3, \@tds);

# ICMP types
%gottypes = map { $_, 1 }
		map { $_ =~ /^(\d+)\-(\d+)$/ ? ( $1 .. $2 ) : ( $_ ) }
			split(/,/, $rule->{'icmptypes'});
$icmptypes = "<select name=icmptypes size=5 multiple>\n";
for($i=0; $i<@icmptypes; $i++) {
	if ($icmptypes[$i] || $gottypes{$i}) {
		$icmptypes .= sprintf "<option value=%d %s>%s</option>\n",
			$i, $gottypes{$i} ? "selected" : "",
			$icmptypes[$i] || "Type $i";
		}
	}
$icmptypes .= "</select>\n";
print &ui_table_row($text{'edit_icmptypes'}, $icmptypes, 1, \@tds);

# TCP flags
%gotflags = map { $_, 1 } split(/,/, $rule->{'tcpflags'});
$tcpflags = "<select name=tcpflags size=5 multiple>\n";
foreach $i (@tcpflags) {
	$tcpflags .= sprintf "<option value=%s %s>%s</option>\n",
		$i, $gotflags{$i} ? "selected" : "", $i;
	}
foreach $i (@tcpflags) {
	$tcpflags .= sprintf "<option value=!%s %s>%s</option>\n",
		$i, $gotflags{"!$i"} ? "selected" : "", &text('edit_not', $i);
	}
$tcpflags .= "</select>\n";
print &ui_table_row($text{'edit_tcpflags'}, $tcpflags, 1, \@tds);

# Limit directive
print &ui_table_row($text{'edit_limit'},
	      &ui_select("limit", $rule->{'limit'} ? $rule->{'limit'}->[0] : "",
			 [ [ "", "<$text{'edit_unlimited'}>" ],
			   [ "src-addr", $text{'edit_src-addr'} ],
			   [ "src-port", $text{'edit_src-port'} ],
			   [ "dst-addr", $text{'edit_dst-addr'} ],
			   [ "dst-port", $text{'edit_dst-port'} ] ])." ".
	      &ui_textbox("limit2", $rule->{'limit'} ? $rule->{'limit'}->[1]
						     : "", 6),
	      3, \@tds);

# Destination ports directive
print &ui_table_row($text{'edit_dstport'},
    &ui_opt_textbox("dstport",
	$rule->{'dst-port'} ? join(" ", @{$rule->{'dst-port'}}) : undef,
	30, $text{'edit_pany'}), 3, \@tds);

# Source ports directive
print &ui_table_row($text{'edit_srcport'},
    &ui_opt_textbox("srcport",
	$rule->{'src-port'} ? join(" ", @{$rule->{'src-port'}}) : undef,
	30, $text{'edit_pany'}), 3, \@tds);

print &ui_table_end();

if ($in{'new'}) {
	print &ui_form_end([ [ 'create', $text{'create'} ] ], "100%");
	}
else {
	print &ui_form_end([ [ 'save', $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ], "100%");
	}

&ui_print_footer("", $text{'index_return'});

# orblock_input(name, &orblock)
sub orblock_input
{
return $text{'edit_orblock'}." ".
       &ui_textbox($_[0], join(" ", @{$_[1]}), 50).
       &ui_hidden($_[0]."_orblock", 1);
}

# yes_no_ignored_input(name)
sub yes_no_ignored_input
{
local $mode = $rule->{$_[0]} && $rule->{$_[0]."_not"} ? 2 :
	      $rule->{$_[0]} ? 1 : 0;
return &ui_radio($_[0], $mode,
		 [ [ 1, $text{'yes'} ],
		   [ 0, $text{'no'} ] ]);
}

