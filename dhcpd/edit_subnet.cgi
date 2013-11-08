#!/usr/local/bin/perl
# edit_subnet.cgi
# Edit or create a subnet

require './dhcpd-lib.pl';
require './params-lib.pl';
&ReadParse();
$conf = &get_config();
($par, $sub) = &get_branch('sub');
$mems = $par->{'members'};
$sconf = $sub->{'members'};

# check acls
%access = &get_module_acl();
&error_setup($text{'eacl_aviol'});
if ($in{'new'}) {
	&error("$text{'eacl_np'} $text{'eacl_pis'}")
		unless &can('c', \%access, $sub) && &can('rw', \%access, $par);
	}
else {
	&error("$text{'eacl_np'} $text{'eacl_pss'}")
		if !&can('r', \%access, $sub);
	}

# display
if ($in{'sidx'} ne "") {
	local $s = $conf->[$in{'sidx'}];
	$desc = &text('ehost_shared', $s->{'values'}->[0]);
	}
&ui_print_header($desc, $in{'new'} ? $text{'esub_crheader'} : $text{'esub_edheader'}, "");

foreach $s (&find("shared-network", $conf)) {
	if ($in{'sidx'} eq $s->{'index'}) {
		$s_parent = $s;
		}
	}

print "<form action=save_subnet.cgi method=post>\n";
print "<input name=ret value=\"$in{'ret'}\" type=hidden>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'esub_tabhdr'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'esub_desc'}</b></td>\n";
printf "<td colspan=3><input name=desc size=60 value='%s'></td> </tr>\n",
	$sub ? &html_escape($sub->{'comment'}) : "";

print "<tr> <td><b>$text{'esub_naddr'}</b></td>\n";
printf "<td><input name=network size=25 value=\"%s\"></td>\n",
	$sub ? $sub->{'values'}->[0] : "";

print "<td><b>$text{'esub_nmask'}</b></td>\n";
printf "<td><input name=netmask size=15 value=\"%s\"></td> </tr>\n",
	$sub ? $sub->{'values'}->[2] : "";

@range = $sub ? &find("range", $sub->{'members'}) : ();
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

if (!defined($in{'ret'})) {
	print "<tr> <td><b>$text{'esub_shnet'}</b></td>\n";
	print "<td><select name=parent>\n";
	printf "<option value=\"\" '%s'>&lt;%s&gt;</option>\n",
		$s_parent ? "" : "checked", $text{'esub_none'};
	foreach $s (&find("shared-network", $conf)) {
		printf "<option value=\"%s\" %s>%s</option>\n",
			$s->{'index'},
			$s eq $s_parent ? "selected" : "",
			$s->{'values'}->[0]
				if &can('rw', \%access, $s);
		}
	print "</select></td>\n";
	}
else {
	print "<input name=parent type=hidden value=$s_parent->{'index'}>\n";
	print "<tr> <td>&nbsp;</td> <td>&nbsp;</td>\n";
	}

&display_params($sconf, "subnet");

foreach $h (&find("host", $mems)) {
	push(@host, $h);
# if &can('r', \%access, $h);
	}
foreach $g (&find("group", $mems)) {
	push(@group, $g);
# if &can('r', \%access, $g);
	}
foreach $s (&find("subnet", $mems)) {
	foreach $h (&find("host", $s->{'members'})) {
		push(@host, $h);
# if &can('r', \%access, $h);
		$insubn{$h} = $s->{'index'};
		}
	foreach $g (&find("group", $s->{'members'})) {
		push(@group, $g);
# if &can('r', \%access, $g);
		$insubn{$g} = $s->{'index'};
		}
	}
@host = sort { $a->{'values'}->[0] cmp $b->{'values'}->[0] } @host;
# @group = sort { @{$a->{'members'}} <=> @{$b->{'members'}} } @group;

print "<tr> <td valign=top><b>$text{'esub_hosts'}</b></td>\n";
print "<td><select name=hosts size=3 multiple>\n";
foreach $h (@host) {
	next if !&can('r', \%access, $h);
	printf "<option value=\"%s,%s\" %s>%s</option>\n",
		$h->{'index'}, $insubn{$h},
		(!$in{'new'}) && $insubn{$h} eq $sub->{'index'} ? "selected" : "",
		$h->{'values'}->[0];
	}
print "</select></td>\n";

print "<td valign=top><b>$text{'esub_groups'}</b></td>\n";
print "<td><select name=groups size=3 multiple>\n";
foreach $g (@group) {
	local $gm = 0;
	next if !&can('r', \%access, $g);
	foreach $h (@{$g->{'members'}}) {
		if ($h->{'name'} eq "host") { $gm++; }
		}
	printf "<option value=\"%s,%s\" %s>%s</option>\n",
		$g->{'index'}, $insubn{$g},
		(!$in{'new'}) && $insubn{$g} eq $sub->{'index'} ? "selected" : "",
		&group_name($gm, $g);
	}
print "</select></td>\n";

if (!$in{'new'}) {
	# inaccessible hosts in this subnet
	foreach $h (@host) {
		if (!&can('r', \%access, $h) && $insubn{$h} eq $sub->{'index'}) {
			print "<input name=hosts value=\"$h->{'index'},$sub->{'index'}\" type=hidden>\n";
			}
		}
	# inaccessible groups in this subnet
	foreach $g (@group) {
		if (!&can('r', \%access, $g) && $insubn{$g} eq $sub->{'index'}) {
			print "<input name=groups value=\"$g->{'index'},$sub->{'index'}\" type=hidden>\n";
			}
		}
	}

print "</table></td></tr></table>\n";
print "<input type=hidden name=sidx value=\"$in{'sidx'}\">\n";
if (!$in{'new'}) {
	# Show buttons for existing subnet
	print "<input type=hidden name=idx value=\"$in{'idx'}\">\n";
	print "<table width=100%><tr>\n";
	print "<td><input type=submit value=\"$text{'save'}\"></td>\n"
		if &can('rw', \%access, $sub);
	print "<td align=center><input type=submit name=options value=\"", 
		  &can('rw', \%access, $sub) ? $text{'butt_eco'} : $text{'butt_vco'},
		  "\"></td>\n";
	if ($access{'r_leases'}) {
		print "<td align=center><input type=submit name=leases ",
		      "value=\"$text{'butt_leases'}\"></td>\n";
		}
	print "<td align=right><input type=submit name=delete ",
	      "value=\"$text{'delete'}\"></td>\n" if &can('rw', \%access, $sub, 1);
	print "</tr></table>\n";
	print "<a href=\"edit_host.cgi?new=1&sidx=$in{'sidx'}&uidx=$in{'idx'}"
		."&ret=subnet\">$text{'index_addhst'}</a>&nbsp;&nbsp;\n"
			if &can('rw', \%access, $sub);
	print "<a href=\"edit_group.cgi?new=1&sidx=$in{'sidx'}&uidx=$in{'idx'}"
		."&ret=subnet\">$text{'index_addhstg'}</a><p>\n"
			if &can('rw', \%access, $sub);
	}
else {
	# Show create button for new subnet
	print "<input type=hidden name=new value=1>\n";
	print "<input type=submit value=\"$text{'create'}\">\n";
	}

if ($config{'dhcpd_version'} >= 3 && !$in{'new'}) {
	# Display address pools
	print &ui_hr();
	print &ui_subheading($text{'esub_pools'});
	local $pn = 1;
	foreach $p (&find('pool', $sconf)) {
		push(@links, "edit_pool.cgi?uidx=$in{'idx'}&sidx=$in{'sidx'}&idx=$p->{'index'}");
		push(@titles, &text('esub_pool', $pn));
		push(@icons, "images/pool.gif");
		$pn++;
		}
	if ($pn == 1) {
		print "$text{'esub_poolnone'}<p>\n";
		}
	else {
		&icons_table(\@links, \@titles, \@icons, 5);
		}
	print "<a href='edit_pool.cgi?uidx=$in{'idx'}&sidx=$in{'sidx'}&new=1'>",
	      "$text{'esub_pooladd'}</a><br>\n";
	}

print "</form>\n";
if ($in{'ret'} eq "shared") {
	&ui_print_footer("edit_shared.cgi?idx=$in{'sidx'}", $text{'esub_retshar'});
	}
else {
	&ui_print_footer("", $text{'esub_return'});
	}

