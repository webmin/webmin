#!/usr/local/bin/perl
# Display a form for editing or creating a NAT rule

require './ipfilter-lib.pl';
&ReadParse();
$rules = &get_ipnat_config();

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
		&webmin_log("delsel", "nat", undef,
			    { 'count' => scalar(@nums) });
		}
	&redirect("");
	exit;
	}

if ($in{'newmap'} || $in{'newrdr'}) {
	&ui_print_header(undef, $text{'nat_title1'}, "");
	$rdr = $in{'newrdr'} ? 1 : 0;
	$rule = { 'action' => $rdr ? 'rdr' : 'map',
		  'active' => 1,
		  'toip' => '0.0.0.0', 'tomask' => 32 };
	}
else {
	$rule = $rules->[$in{'idx'}];
	&ui_print_header(undef, $text{'nat_title2'}, "");
	$rdr = $rule->{'action'} eq 'rdr' ? 1 : 0;
	}

if (!$rdr) {
	# Javascript for disabling fields
	print <<EOF;
<script>
function from_change(dis)
{
var f = document.forms[0];
for(i=0; i<f.elements.length; i++) {
        e = f.elements[i];
	if (e.name.substring(0, 4) == "from" &&
	    e.name != "frommode" && e.name != "fromip" &&
	    e.name != "frommask") {
		e.disabled = dis;
		}
	}
}
</script>
EOF
	}

print &ui_form_start("save_nat.cgi", "post");
print &ui_hidden("new", $in{'newmap'} || $in{'newrdr'}),"\n";
print &ui_hidden("idx", $in{'idx'}),"\n";
print &ui_hidden("before", $in{'before'}),"\n";
print &ui_hidden("after", $in{'after'}),"\n";
@tds = ( "width=20%", undef );

print &ui_table_start($text{'nat_header1'}, "width=100%", 2);

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

# NAT mode
if ($rdr) {
	print &ui_table_row($text{'nat_action'},
			    $text{'action_rdr'});
	print &ui_hidden("action", "rdr"),"\n";
	}
else {
	print &ui_table_row($text{'nat_action'},
		    &ui_select("action", $rule->{'action'},
			       [ [ "map", $text{'action_map'} ],
				 [ "bimap", $text{'action_bimap'} ],
				 [ "map-block", $text{'action_map-block'} ] ]));
	}
print &ui_table_end(),"<p>\n";

if (!$rdr) {
	# Show section for source
	print &ui_table_start($text{'nat_header2'}, "width=100%", 2);

	# NAT interface
	print &ui_table_row($text{'nat_iface'},
			    &interface_choice("iface", $rule->{'iface'}, 1));

	# Source mode and address
	print &ui_table_row($text{'nat_frommode'},
	    &ui_radio("frommode", $rule->{'from'} ? 1 : 0,
		      [ [ 0, &text('nat_frommode0',
			           &ipmask_input("from"))."<br>",
			     "onClick='from_change(true)'" ],
			[ 1, $text{'nat_frommode1'},
			     "onClick='from_change(false)'" ] ]));
	($ft, $pt) = &object_input($rule, "from");
	print &ui_table_row($text{'edit_from'}, $ft);
	print &ui_table_row($text{'edit_portfrom'}, $pt);
	($ft, $pt) = &object_input($rule, "fromto");
	print &ui_table_row($text{'edit_to'}, $ft);
	print &ui_table_row($text{'edit_portto'}, $pt);

	print &ui_table_end(),"<p>\n";

	# Show section for destination
	print &ui_table_start($text{'nat_header3'}, "width=100%", 2);

	# Destination address
	print &ui_table_row($text{'nat_tomode'},
	     &ui_radio("tomode", $rule->{'tostart'} ? 1 :
				 $rule->{'toip'} eq '0.0.0.0' &&
			          $rule->{'tomask'} == 32 ? 2 : 0,
		      [ [ 2, $text{'nat_tomode2'}."<br>" ],
			[ 0, &text('nat_tomode0',
			           &ipmask_input("to"))."<br>" ],
			[ 1, &text('nat_tomode1',
			   &ui_textbox("tostart", $rule->{'tostart'}, 15),
			   &ui_textbox("toend", $rule->{'toend'}, 15)) ] ]));

	# Port mapping
	print &ui_table_row($text{'nat_portmap'},
		&ui_radio("portmapmode", $rule->{'portmap'} ? 1 : 0,
		  [ [ 0, $text{'nat_portmap0'}."<br>" ],
		    [ 1, &text('nat_portmap1',
			&protocol_input("portmap", $rule->{'portmap'}, 0, 1),
			&ui_checkbox("portmapnoauto", 1,"",
				     $rule->{'portmapfrom'}),
			&ui_textbox("portmapfrom", $rule->{'portmapfrom'}, 5),
			&ui_textbox("portmapto", $rule->{'portmapto'}, 5)) ] ]));

	# Proxy mapping
	print &ui_table_row($text{'nat_proxy'},
		&ui_radio("proxymode", $rule->{'proxyport'} ? 1 : 0,
		  [ [ 0, $text{'nat_proxy0'}."<br>" ],
		    [ 1, &text('nat_proxy1',
			  &ui_textbox("proxyport", $rule->{'proxyport'}, 5),
			  &ui_textbox("proxyname", $rule->{'proxyname'}, 5),
			  &protocol_input("proxyproto",
					  $rule->{'proxyproto'}, 0, 0)) ] ]));

	print &ui_table_end(),"<p>\n";

	# Show section for other options
	print &ui_table_start($text{'nat_header4'}, "width=100%", 2);
	print "<table>\n";

	print "<tr> <td>",&ui_checkbox("proto", 1, $text{'nat_proto'},
				       $rule->{'proto'}),"</td>\n";
	print "<td>",&protocol_input("protoproto", $rule->{'proto'}, 0, 1),
	      "</td> </tr>\n";

	print "<tr> <td colspan=2>",&ui_checkbox("frag", 1, $text{'nat_frag'},
				       $rule->{'frag'}),"</td> </tr>\n";

	print "<tr> <td>",&ui_checkbox("mssclamp", 1, $text{'nat_clampmss'},
				       $rule->{'mssclamp'}),"</td>\n";
	print "<td>",&ui_textbox("mss", $rule->{'mssclamp'}, 5)," ",
	      "$text{'nat_bytes'}</td> </tr>\n";

	# Proxy mapping
	print "<tr> <td>",&ui_checkbox("oproxy", 1, $text{'nat_oproxy'},
				       $rule->{'oproxyport'}),"</td>\n";
	print "<td>",&text('nat_oproxy1',
			  &ui_textbox("oproxyport", $rule->{'oproxyport'}, 5),
			  &ui_textbox("oproxyname", $rule->{'oproxyname'}, 5),
			  &protocol_input("oproxyproto",
					  $rule->{'oproxyproto'}, 0, 0)),"</td> </tr>\n";

	print &ui_table_end();
	}
else {
	# Show section for source
	print &ui_table_start($text{'nat_header5'}, "width=100%", 2);

	# NAT interface
	print &ui_table_row($text{'nat_iface'},
			    &interface_choice("iface", $rule->{'iface'}, 1));

	# Packets to redirect
	print &ui_table_row($text{'nat_redir'},
			    &ipmask_input("from"));

	# Destination ports
	print &ui_table_row($text{'nat_dports'},
	    &ui_radio("dportsmode", $rule->{'dport2'} ? 1 : 0,
		      [ [ 0, &text('nat_dports0',
			   &ui_textbox("dport", $rule->{'dport1'}, 10)) ],
			[ 1, &text('nat_dports1',
			   &ui_textbox("dport1", $rule->{'dport1'}, 10),
			   &ui_textbox("dport2", $rule->{'dport2'}, 10)) ] ]));

	print &ui_table_row($text{'nat_rdrproto'},
		&protocol_input("rprproto",  $rule->{'rdrproto'}, 0, 1));

	print &ui_table_end(),"<p>\n";

	# Show section for destination
	print &ui_table_start($text{'nat_header6'}, "width=100%", 2);

	print &ui_table_row($text{'nat_rdrip'},
	    &ui_textarea("rdrip", join("\n", @{$rule->{'rdrip'}}), 3, 50));

	print &ui_table_row($text{'nat_rdrport'},
		&ui_textbox("rdrport", $rule->{'rdrport'}, 10));

	print &ui_table_end(),"<p>\n";

	# Show section for other options
	print &ui_table_start($text{'nat_header4'}, "width=100%", 2);
	print "<table>\n";

	print "<tr> <td colspan=2>",&ui_checkbox("round-robin", 1,
						 $text{'nat_robin'},
				       $rule->{'round-robin'}),"</td> </tr>\n";

	print "<tr> <td colspan=2>",&ui_checkbox("frag", 1, $text{'nat_frag'},
				       $rule->{'frag'}),"</td> </tr>\n";

	print "<tr> <td>",&ui_checkbox("mssclamp", 1, $text{'nat_clampmss'},
				       $rule->{'mssclamp'}),"</td>\n";
	print "<td>",&ui_textbox("mss", $rule->{'mssclamp'}, 5)," ",
	      "$text{'nat_bytes'}</td> </tr>\n";

	print &ui_table_end();
	}

if ($in{'newmap'} || $in{'newrdr'}) {
	print &ui_form_end([ [ 'create', $text{'create'} ] ], "100%");
	}
else {
	print &ui_form_end([ [ 'save', $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ], "100%");
	}
if (!$rdr) {
	$dis = $rule->{'from'} ? "false" : "true";
	print "<script>from_change($dis);</script>\n";
	}
&ui_print_footer("", $text{'index_return'});

# ipmask_input(prefix)
sub ipmask_input
{
local ($pfx) = @_;
return &ui_textbox($pfx."ip", $rule->{$pfx."ip"}, 15)." / ".
       &ui_textbox($pfx."mask", $rule->{$pfx."mask"}, 15);
}

