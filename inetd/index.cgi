#!/usr/local/bin/perl
# index.cgi
# Display a list of known services, built from those handled by inetd and
# from the services file

require './inetd-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("inetd", "man", "doc", "howto"));

# break down into rpc and internet services
$j = 0;
foreach $i (&list_inets()) {
	if ($i->[2]) {
		# rpc service
		$i->[3] =~ /^(\S+)\//;
		if ($i->[1]) { $rpc_active{$1} = $j; }
		else { $rpc_disabled{$1} = $j; }
		}
	else {
		# internet service
		if ($i->[1]) { $int_active{$i->[3],$i->[5]} = $j; }
		else { $int_disabled{$i->[3],$i->[5]} = $j; }
		}
	$j++;
	}

print "<form action=edit_serv.cgi>\n";
print "<a href=\"edit_serv.cgi?new=1\">$text{'index_newservice'}</a>.<br>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'index_service'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";
$i = 0;
@slist = &list_services();
if ($config{'sort_mode'} == 1) {
	@slist = sort { uc($a->[1]) cmp uc($b->[1]) } @slist;
	}
elsif ($config{'sort_mode'} == 2) {
	@slist = sort { (defined($int_active{$b->[1],$b->[3]}) ? 2 :
			 defined($int_disabled{$b->[1],$b->[3]}) ? 1 : 0) <=>
			(defined($int_active{$a->[1],$a->[3]}) ? 2 :
			 defined($int_disabled{$a->[1],$a->[3]}) ? 1 : 0) }
		      @slist;
	}
foreach $s (@slist) {
	$ia = $int_active{$s->[1],$s->[3]};
	$id = $int_disabled{$s->[1],$s->[3]};
	if ($ia =~ /\d/) { $op = "<b>"; $cl = "</b>"; $ip = $ia; }
	elsif ($id =~ /\d/) { $op = "<i><b>"; $cl = "</b></i>"; $ip = $id; }
	elsif (!$config{'show_empty'}) { next; }
	else { $op = $cl = $ip = ""; }
	if ($i%4 == 0) { print "<tr>\n"; }
	print "<td>$op";
	print "<a href=\"edit_serv.cgi?spos=$s->[5]&ipos=$ip\">",
	      &html_escape($s->[1]),"</a>(",&html_escape($s->[3]),")";
	print "$cl</td>\n";
	if ($i++%4 == 3) { print "</tr>\n"; }
	}
print "</table></td></tr></table>\n";

print "<table width=100%><tr>\n";
print "<td><a href='edit_serv.cgi?new=1'>$text{'index_newservice'}</a></td>\n";
if (!$config{'show_empty'}) {
	print "<td align=right>\n";
	print "<input type=submit value='$text{'index_edit'}'>\n";
	print "<input name=name size=12>\n";
	print "<select name=proto>\n";
	foreach $p (&list_protocols()) {
		printf "<option value=%s %s>%s\n",
			$p, $p eq "tcp" ? "selected" : "", $p;
		}
	print "</select></td>\n";
	}
print "</tr></table></form>\n";

print &ui_hr();
print "<a href=\"edit_rpc.cgi?new=1\">$text{'index_newrpc'}</a>. <br>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'index_rpc'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";
$i = 0;
@rlist = &list_rpcs();
if ($config{'sort_mode'} == 1) {
	@rlist = sort { uc($a->[1]) cmp uc($b->[1]) } @rlist;
	}
elsif ($config{'sort_mode'} == 2) {
	@rlist = sort { ($rpc_active{$b->[1]} ? 2 :
			 $rpc_disabled{$b->[1]} ? 1 : 0) <=>
			($rpc_active{$a->[1]} ? 2 :
			 $rpc_disabled{$a->[1]} ? 1 : 0) } @rlist;
	}
foreach $r (@rlist) {
	if ($i%4 == 0) { print "<tr $cb>\n"; }
	$ra = $rpc_active{$r->[1]};
	$rd = $rpc_disabled{$r->[1]};
	$ranum = $rpc_active{$r->[2]};
	$rdnum = $rpc_disabled{$r->[2]};
	if ($ra =~ /\d/) { $op = "<b>"; $cl = "</b>"; $rp = $ra; }
	elsif ($ranum =~ /\d/) { $op = "<b>"; $cl = "</b>"; $rp = $ranum; }
	elsif ($rd =~ /\d/) { $op = "<i>"; $cl = "</i>"; $rp = $rd; }
	elsif ($rdnum =~ /\d/) { $op = "<i>"; $cl = "</i>"; $rp = $rdnum; }
	else { $op = $cl = $rp = ""; }
	print "<td>$op";
	print "<a href=\"edit_rpc.cgi?rpos=$r->[4]&ipos=$rp\">",
	      &html_escape($r->[1]),"</a>$cl</td>\n";
	if ($i++%4 == 3) { print "</tr>\n"; }
	}
print "</table></td></tr></table>\n";
print "<a href=\"edit_rpc.cgi?new=1\">$text{'index_newrpc'}</a>. <p>\n";

print &ui_hr();
print "<form action=restart_inetd.cgi>\n";
print "<table width=100%> <tr>\n";
print "<td><input type=submit value=\"$text{'index_apply'}\"></td>\n";
print "<td valign=top> $text{'index_applymsg'}</td>\n";
print "</tr> </table> </form>\n";

&ui_print_footer("/", $text{'index'});

