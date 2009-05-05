#!/usr/local/bin/perl
# edit_pool.cgi
# Edit ranges and other options in an address pool

require './dhcpd-lib.pl';
require './params-lib.pl';
&ReadParse();
$conf = &get_config();
if ($in{'sidx'} ne "") {
	$sha = $conf->[$in{'sidx'}]; 
	$sub = $sha->{'members'}->[$in{'uidx'}];
	}
else { $sub = $conf->[$in{'uidx'}]; }

# check acls
%access = &get_module_acl();
&error_setup($text{'eacl_aviol'});
&error("$text{'eacl_np'} $text{'eacl_pss'}") if !&can('r',\%access,$sub);

# display
if ($sub->{'name'} eq 'subnet') {
	$desc = &text('ehost_subnet', $sub->{'values'}->[0],
				      $sub->{'values'}->[2]);
	}
else {
	$desc = &text('ehost_shared', $sub->{'values'}->[0]);
	}
if ($in{'new'}) {
	&ui_print_header($desc, $text{'pool_create'}, "");
	}
else {
	&ui_print_header($desc, $text{'pool_edit'}, "");
	$pool = $sub->{'members'}->[$in{'idx'}];
	}

print "<form action=save_pool.cgi method=post>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<input type=hidden name=uidx value='$in{'uidx'}'>\n";
print "<input type=hidden name=sidx value='$in{'sidx'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'pool_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

@range = $pool ? &find("range", $pool->{'members'}) : ();
print "<tr> <td valign=top><b>$text{'esub_arange'}</b></td> <td colspan=3>\n";
for($i=0; $i<=@range; $i++) {
	$r = $range[$i];
	local $dyn = ($r->{'values'}->[0] eq "dynamic-bootp");
	printf "<input name=range_low_$i size=15 value=\"%s\"> - \n",
		$r->{'values'}->[$dyn];
	printf "<input name=range_hi_$i size=15 value=\"%s\">&nbsp;\n",
		$r->{'values'}->[$dyn+1];
	printf "<input type=checkbox name=range_dyn_$i value=1 %s>\n",
		$dyn ? "checked" : "";
	print "$text{'esub_dbooptpq'}<br>\n";
	}
print "</td> </tr>\n";

print "<tr>\n";

@failover = $pool ? &find("failover", $pool->{'members'}) : ();
local $peer = $failover[0]->{'values'}->[1];
print "<td><b>$text{'esub_fopeer'}</b></td> <td nowrap>\n";
printf "<input type=radio name=failover_peer_def value=1 %s> None\n", $peer ? "" : "checked";
printf "<input type=radio name=failover_peer_def value=0 %s>\n", $peer ? checked : "";
printf "<input name=failover_peer size=20 value=\"%s\"> </td> \n", $peer;
print "</tr>\n";

print "<tr> <td valign=top><b>$text{'pool_allow'}</b></td>\n";
print "<td><textarea name=allow rows=4 cols=25>",
	join("\n", map { $_->{'text'} } &find("allow", $pool->{'members'})),
	"</textarea></td>\n";

print "<td valign=top><b>$text{'pool_deny'}</b></td>\n";
print "<td><textarea name=deny rows=4 cols=25>",
	join("\n", map { $_->{'text'} } &find("deny", $pool->{'members'})),
	"</textarea></td> </tr>\n";

&display_params($pool->{'members'}, "pool");

print "</table></td></tr></table>\n";
print "<table width=100%><tr>\n";
if ($in{'new'}) {
	# Show create button for new subnet
	print "<td><input type=submit value='$text{'create'}'></td>\n"
		if &can('rw',\%access,$sub);
	}
else {
	# Show buttons for existing pool
	print "<td><input type=submit value='$text{'save'}'></td>\n"
		if &can('rw',\%access,$sub);
	print "<td align=right><input type=submit name=delete ",
	      "value='$text{'delete'}'></td>\n" if &can('rw',\%access,$sub);
	}
print "</tr></table>\n";
print "</form>\n";
&ui_print_footer("edit_subnet.cgi?sidx=$in{'sidx'}&idx=$in{'uidx'}",
	$text{'pool_return'});

