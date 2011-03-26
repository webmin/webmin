#!/usr/bin/perl
# list_rules.cgi
# Display a list of all active rules
require './itsecur-lib.pl';

&can_use_error("rules");
&header($text{'rules_title'}, "",
	undef, undef, undef, undef, &apply_button());
print "<hr>\n";


# 				0-No.	1-Source,2-Destination,	3-Services,	4-Time,	5-Action,	6-Enabled,	7-Comment
local @CW=(	"5%",	"15%",	"15%",			"20%",		"5%",		"5%",			"5%",			"20%");
$C_drop="#FFCCcc";
$C_reject="#FFDDAA";
$C_accept="";
$C_disabled="#FF3333";
$C_separator="#ffffcc";

local $Row_Color="";

@rules = &list_rules();
@servs = &list_services();
$edit = &can_edit("rules");
$times = &supports_time() && &list_times() > 0;
if (@rules) {
	if ($edit) {
		print "<a href='edit_rule.cgi?new=1'>$text{'rules_add'}</a>\n";
		print "&nbsp;" x 2;
		print "<a href='edit_sep.cgi?new=1'>$text{'rules_sadd'}</a>\n";
		print "<br>\n";
		print "<form action=enable_rules.cgi method=post>\n";
		}
	$cols = $times ? 8 : 7;
	print "<table border>\n";
	print "<tr $tb> ",
	      "<td width=$CW[0]><b>$text{'rule_num'}</b></td> ",
	      "<td width=$CW[1]><b>$text{'rule_source'}</b></td> ",
	      "<td width=$CW[2]><b>$text{'rule_dest'}</b></td> ",
	      "<td width=$CW[3]><b>$text{'rules_service'}</b></td> ",
	      ($times ? "<td><b>$text{'rule_time'}</b></td> " : ""),
	      "<td width=$CW[5]><b>$text{'rule_action'}</b></td> ",
	      "<td width=$CW[6]><b>$text{'rule_enabled'}</b></td> ",
	      ($config{'show_desc'} ? "<td width=$CW[7]><b>$text{'rules_desc'}</b></td> " :
			"<td width=10><b>$text{'rules_move'}</b></td>"),
	      "</tr>\n";
	foreach $r (@rules) {
		if ($r->{'sep'}){
				$Row_Color="bgcolor=\"$C_separator\" ";				
		} elsif (!$r->{'enabled'}){
				$Row_Color="bgcolor=\"$C_disabled\" ";
		} elsif ( $r->{'action'} eq "drop" ){
				$Row_Color="bgcolor=\"$C_drop\" ";
		} elsif ( $r->{'action'} eq "reject" ){
				$Row_Color="bgcolor=\"$C_reject\" ";				
		} else {
			   $Row_Color=""; 
		}

					# case('accept') {}
					# case('allow') {}
   				# case('drop') {}
					#case('reject') {}
					#case('ignore') {}
			

			   	
		print "<tr $Row_Color $cb>\n";
		if ($r->{'sep'}) {
			# Actually a separator - just show it's description
			print "<td colspan=$cols><b><a href='edit_sep.cgi?idx=$r->{'index'}'>$r->{'desc'}</b></a></td>\n";
			}
		else {
			# Show full rule details			

			
			print "<td width=$CW[0]>";
			if ($edit) {
				print "<input type=checkbox name=r value=$r->{'index'}>&nbsp;";
				}
			print "<a href='edit_rule.cgi?",
			      "idx=$r->{'index'}'>$r->{'num'}</a></td>\n";
			print "<td width=$CW[1]>",
				&group_names_link($r->{'source'}, 'rules'),
				"</td>\n";
			print "<td width=$CW[2]>",
				&group_names_link($r->{'dest'}, 'rules',
						  &allow_action($r) ? 'dest' : undef),
				"</td>\n";
			print "<td width=$CW[3]>",&protocol_names($r->{'service'},\@servs),"</td>\n";
			if ($times) {
				print "<td>",$r->{'time'} eq '*' ?
					$text{'rule_anytime'} :
					$r->{'time'},"</td>\n";
				}
			print "<td width=$CW[5]>",$text{'rule_'.$r->{'action'}},
			      $r->{'log'} ? " $text{'rules_log'}" : "","</td>\n";
			print "<td width=$CW[6]>",$r->{'enabled'} ? $text{'yes'} :
				"<font color=#ff0000>$text{'no'}</font>",
			      "</td>\n";
			if ($config{'show_desc'}) {
				print "<td width=$CW[7]>",$r->{'desc'} eq "*" ? "<br>"
							: $r->{'desc'},"</td>\n";
				}
			else {
				if ($r eq $rules[0] || !$edit) {
					print "<td><img src=images/gap.gif>\n";
					}
				else {
					print "<td><a href='up.cgi?idx=$r->{'index'}'>",
					      "<img src=images/up.gif border=0></a>\n";
					}
				if ($r eq $rules[$#rules] || !$edit) {
					print "<img src=images/gap.gif></td>\n";
					}
				else {
					print "<a href='down.cgi?idx=$r->{'index'}'>",
					      "<img src=images/down.gif border=0></a></td>\n";
					}
				}
			}
		print "</tr>\n";
		}
	print "</table>\n";
	}
else {
	print "<b>$text{'rules_none'}</b><p>\n";
	}
if ($edit) {
	print "<a href='edit_rule.cgi?new=1'>$text{'rules_add'}</a>\n";
	print "&nbsp;" x 2;
	print "<a href='edit_sep.cgi?new=1'>$text{'rules_sadd'}</a>\n";
	print "<p>\n";
	}
if ($edit && @rules) {
	print "<input type=submit name=enable value='$text{'rules_enable'}'>\n";
	print "<input type=submit name=disable value='$text{'rules_disable'}'>\n";

	print "&nbsp;\n";
	print "<input type=submit name=logon value='$text{'rules_logon'}'>\n";
	print "<input type=submit name=logoff value='$text{'rules_logoff'}'>\n";
	print "&nbsp;\n";
	print "<input type=submit name=delete value='$text{'rules_delete'}'>\n";
	print "</form>\n";
	}

print "<hr>\n";
&footer("", $text{'index_return'});

