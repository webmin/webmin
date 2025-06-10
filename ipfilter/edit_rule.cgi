#!/usr/local/bin/perl
# Display a form for editing or creating a firewall rule

require './ipfilter-lib.pl';
&ReadParse();
$rules = &get_config();

if ($in{'delsel'}) {
	# Special case - deleting selected rules
	@nums = sort { $b cmp $a } split(/\0/, $in{'d'});
	if (@nums) {
		&lock_file($rules->[$nums[0]]->{'file'});
		foreach $n (@nums) {
			&delete_rule($rules->[$n]);
			}
		&flush_file_lines();
		&unlock_file($rules->[$nums[0]]->{'file'});
		&webmin_log("delsel", "rule", undef,
			    { 'count' => scalar(@nums) });
		}
	&redirect("");
	exit;
	}

if ($in{'new'}) {
	&ui_print_header(undef, $text{'edit_title1'}, "");
	$rule = { 'action' => 'pass',
		  'all' => 1,
		  'active' => 1,
		  'dir' => 'in',
		  'quick' => 1 };
	}
else {
	$rule = $rules->[$in{'idx'}];
	&ui_print_header(undef, $text{'edit_title2'}, "");
	}

# Javascript for disabling fields
print <<EOF;
<script>
function all_change(dis)
{
var f = document.forms[0];
for(i=0; i<f.elements.length; i++) {
        e = f.elements[i];
	if (e.name.substring(0, 3) != "tos" &&
	    (e.name.substring(0, 4) == "from" ||
	     e.name.substring(0, 2) == "to")) {
		e.disabled = dis;
		}
	}
}
</script>
EOF

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

# Enabled
print &ui_table_row($text{'edit_active'},
		    &ui_radio("active", $rule->{'active'} ? 1 : 0,
			      [ [ 1, $text{'edit_active1'} ],
				[ 0, $text{'edit_active0'} ] ]));

# Rule action and argument
$ra = $rule->{'action'};
push(@action, $ra) if ($ra && &indexof($ra, @actions) < 0);
$acts = "<table cellpadding=1 cellspacing=1>\n";
$i = 0;
%action_fields = ( 'block' => [ 'block_return', 'block_return_dest' ],
		   'log' => [ 'log_pri', 'log_fac', 'log_body', 'log_first',
			      'log_orblock' ],
		   'skip' => [ 'skip' ],
		   'call' => [ 'call', 'call_now' ] );
foreach $a (@actions) {
	$acts .= "<tr> <td>";
	local $ma = $rule->{'action'} eq $a;
	@myfields = @{$action_fields{$a}};
	@notfields = map { @{$action_fields{$_}} }
			 grep { $_ ne $a } (keys %action_fields);
	$acts .= &ui_oneradio("action", $a,
			$text{"laction_".$a} || $text{"action_".$a} || uc($a),
			$ma,
			&js_disable_inputs(\@notfields, \@myfields, "onClick"));
	if ($a eq "block") {
		# Show ICMP block options
		local @codes = ( [ "", $text{'edit_none'} ],
				 [ "rst", $text{'edit_rst'} ] );
		push(@codes, map { [ $_ ] } @icmp_codes);
		push(@codes, [ $rule->{'block-return'} ])
			if ($rule->{'block-return'} &&
			    $rule->{'block-return'} ne "rst" &&
			    &indexof($rule->{'block-return'}, @icmp_codes) < 0);
		$acts .= &ui_select("block_return", $rule->{'block-return'},
				    \@codes, 0, 0, 1, !$ma)."\n";
		$acts .= &ui_checkbox("block_return_dest", 1,
				      $text{'edit_return_dest'},
				      $rule->{'block-return-dest'},
				      undef, !$ma);
		}
	elsif ($a eq "log") {
		# Show logging options
		$acts .= &logging_options("log", 1, !$ma);
		}
	elsif ($a eq "skip") {
		# Show rule to skip to
		$acts .= &ui_textbox("skip", $rule->{'skip'}, 10, !$ma);
		}
	elsif ($a eq "call") {
		# Show function name
		$acts .= &ui_textbox("call", $rule->{'call'}, 20, !$ma)."\n".
			 &ui_checkbox("call_now", 1, $text{'edit_callnow'},
				      $rule->{'call-now'}, undef, !$ma);
		}
	$acts .= "</td> </tr>";
	}
$acts .= "</table>\n";
print &ui_table_row($text{'edit_action'}, $acts,
		    undef, \@tds);

print &ui_table_end(),"<br>\n";

# Show section for source and destination
print &ui_table_start($text{'edit_header2'}, "width=100%", 2);

print &ui_table_row($text{'edit_all'},
    &ui_radio("all", $rule->{'all'} || 0,
	      [ [ 1, $text{'edit_all1'}, "onClick='all_change(true)'" ],
		[ 0, $text{'edit_all0'}, "onClick='all_change(false)'" ] ]));

foreach $f ("from", "to") {
	print &ui_table_hr();
	($ft, $pt) = &object_input($rule, $f);
	print &ui_table_row($text{'edit_'.$f}, $ft);
	print &ui_table_row($text{'edit_port'.$f}, $pt);
	}

print &ui_table_end(),"<br>\n";

# Show section for protocol, ttl, tos
print &ui_table_start($text{'edit_header3'}, "width=100%", 4);

print &ui_table_row($text{'edit_dir'},
    &ui_radio("dir", $rule->{'dir'}, [ [ "in", $text{'dir_in'} ],
				       [ "out", $text{'dir_out'} ] ]));

print &ui_table_row($text{'edit_proto'},
    &protocol_input("proto", $rule->{'proto'}, 1, 0));

print &ui_table_row($text{'edit_tos'},
    &ui_opt_textbox("tos", $rule->{'tos'}, 8, $text{'edit_tosany'}));

print &ui_table_row($text{'edit_ttl'},
    &ui_opt_textbox("ttl", $rule->{'ttl'}, 8, $text{'edit_tosany'}));

print &ui_table_row($text{'edit_on'},
		    &interface_choice("on", $rule->{'on'}));

print &ui_table_row($text{'edit_flags'},
    &ui_opt_textbox("flags1", $rule->{'flags1'}, 8, $text{'edit_flagsany'},
		    undef, 0, [ "flags2" ]).
		    " $text{'edit_flags2'} ".
		    &ui_textbox("flags2", $rule->{'flags2'}, 8,
				!$rule->{'flags1'}));

print &ui_table_row($text{'edit_icmp'},
    &ui_select("icmptype", $rule->{'icmp-type'},
	       [ [ "", $text{'edit_icmpany'} ],
		 map { [ $_ ] } @icmp_types ],
	       0, 0, $rule->{'icmp-type'} ? 1 : 0).
    " $text{'edit_icmpcode'} ".
    &ui_select("icmpcode", $rule->{'icmp-type-code'},
	       [ [ "", $text{'edit_codeany'} ],
		 map { [ $_ ] } @icmp_codes ],
	       0, 0, $rule->{'icmp-code'} ? 1 : 0), 3);

print &ui_table_end(),"<br>\n";

# Show section for other options
print &ui_table_start($text{'edit_header4'}, "width=100%", 2);
print "<table>\n";

print "<tr> <td colspan=2>",&ui_checkbox("quick", 1, $text{'edit_quick'},
			       $rule->{'quick'}),"</td> </tr>\n";

# Show logging options as action
print "<tr> <td>",&ui_checkbox("olog", 1, $text{'edit_olog'},
	       $rule->{'olog'},
	       &js_checkbox_disable("olog", [ ], [ "olog_pri", "olog_fac", "olog_body", "olog_first", "olog_block" ], "onClick")),"</td>\n";
print "<td>",&logging_options("olog", 1, !$rule->{'olog'}),"</td> </tr>\n";
 
# Show tagging ID
print "<tr> <td>",&ui_checkbox("tag", 1, $text{'edit_tag'},
	$rule->{'tag'},
	&js_checkbox_disable("tag", [ ], [ "tagid" ], "onClick")),"</td>\n";
print "<td>",&ui_textbox("tagid", $rule->{'tag'}, 10, !$rule->{'tag'}),
      "</td> </tr>\n";

# Show duplicate destination
print "<tr> <td>",&ui_checkbox("dup_to", 1, $text{'edit_dupto'},
	$rule->{'dup-to'},
	&js_checkbox_disable("dup_to", [ ],
			     [ "dup_toiface", "dup_toiface_other",
			       "dup_toip" ], "onClick")),"</td>\n";
($iface, $ip) = split(/:/, $rule->{'dup-to'});
print "<td>",&interface_choice("dup_toiface", $iface, 1,
			       !$rule->{'dup-to'}),"\n";
print "$text{'edit_duptoip'}\n";
print &ui_textbox("dup_toip", $ip, 13,
		  !$rule->{'dup-to'})," $text{'edit_opt'}</td> </tr>\n";

# Show fast routing destination
print "<tr> <td>",&ui_checkbox("fastroute", 1, $text{'edit_fastroute'},
	$rule->{'fastroute'},
	&js_checkbox_disable("fastroute", [ ],
			     [ "fastrouteiface", "fastrouteiface_other",
			       "fastrouteip" ], "onClick")),"</td>\n";
print "<td>",&interface_choice("fastrouteiface", $rule->{'fastroute'}, 1,
			       !$rule->{'fastroute'}),"\n";
print "$text{'edit_fastrouteip'}\n";
print &ui_textbox("fastrouteip", $rule->{'fastroute-ip'}, 13,
		  !$rule->{'fastroute'})," $text{'edit_opt'}</td> </tr>\n";

# Show reply destination
print "<tr> <td>",&ui_checkbox("reply_to", 1, $text{'edit_replyto'},
	$rule->{'reply-to'},
	&js_checkbox_disable("reply_to", [ ],
			     [ "reply_toiface", "reply_toiface_other",
			       "reply_toip" ], "onClick")),"</td>\n";
print "<td>",&interface_choice("reply_toiface", $rule->{'reply-to'}, 1,
			       !$rule->{'reply-to'}),"\n";
print "$text{'edit_fastrouteip'}\n";
print &ui_textbox("reply_toip", $rule->{'reply-to-ip'}, 13,
		  !$rule->{'reply-to'})," $text{'edit_opt'}</td> </tr>\n";

# Show state keeping options
print "<tr> <td>",&ui_checkbox("keep", 1, $text{'edit_keep'},
       	$rule->{'keep'},
	&js_checkbox_disable("keep", [ ] , [ "keepmode" ], "onClick")),"</td>\n";
print "<td>",&ui_select("keepmode", $rule->{'keep'} || "state",
		[ [ "state", $text{'edit_keepstate'} ],
		  [ "frags", $text{'edit_keepfrags'} ] ],
		1, 0, 0, !$rule->{'keep'}),"<td> </tr>\n";

print &ui_table_end();

if ($in{'new'}) {
	print &ui_form_end([ [ 'create', $text{'create'} ] ], "100%");
	}
else {
	print &ui_form_end([ [ 'save', $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ], "100%");
	}
$dis = $rule->{'all'} ? "true" : "false";
print "<script>all_change($dis);</script>\n";
&ui_print_footer("", $text{'index_return'});

# yes_no_ignored_input(name)
sub yes_no_ignored_input
{
local $mode = $rule->{$_[0]} && $rule->{$_[0]."_not"} ? 2 :
	      $rule->{$_[0]} ? 1 : 0;
return &ui_radio($_[0], $mode,
		 [ [ 1, $text{'yes'} ],
		   [ 0, $text{'no'} ] ]);
}

# logging_options(prefix, split, disable?)
sub logging_options
{
local ($pfx, $split, $dis) = @_;
local $rv;
local $ll = $rule->{$pfx."-level"};
local ($f, $p);
if ($ll =~ /^(\S+)\.(\S+)$/) {
	$p = $2; $f = $1;
	}
elsif ($ll =~ /\S/) {
	$p = $ll;
	}
$rv .= &ui_select($pfx."_pri", $p,
	  [ [ "", $text{'default'} ], map { [ $_ ] } @log_priorities ],
	  0, 0, 1, $dis);
$rv .= " $text{'edit_fac'} ";
$rv .= &ui_select($pfx."_fac", $f,
	  [ [ "", $text{'default'} ], map { [ $_ ] } @log_facilities ],
	  0, 0, 1, $dis)."\n";
$rv .= "<br>&nbsp;&nbsp;&nbsp;\n" if ($_[1]);
$rv .= &ui_checkbox($pfx."_body", 1, $text{'edit_log_body'},
		    $rule->{$pfx.'-body'}, undef, $dis)."\n";
$rv .= &ui_checkbox($pfx."_first", 1, $text{'edit_log_first'},
		    $rule->{$pfx.'-first'}, undef, $dis)."\n";
$rv .= &ui_checkbox($pfx."_orblock", 1, $text{'edit_log_orblock'},
		    $rule->{$pfx.'-or-block'}, undef, $dis)."\n";
return $rv;
}


