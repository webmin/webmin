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

print &ui_form_start("save_subnet.cgi", "post");
print &ui_hidden("ret",$in{'ret'});
print &ui_table_start($text{'esub_tabhdr'}, "width=100%", 4);

print "<tr><td valign=middle><b>$text{'esub_desc'}</b></td>\n";
print "<td valign=middle colspan=3>";
print &ui_textbox("desc", ( $sub ? &html_escape($sub->{'comment'}) : "" ), 60);
print "</td>";
print "</tr>";

print "<tr><td valign=middle><b>$text{'esub_naddr'}</b></td>\n";
print "<td valign=middle>";
print &ui_textbox("network", ( $sub ? $sub->{'values'}->[0] : "" ), 25);
print "</td>";

print "<td valign=middle><b>$text{'esub_nmask'}</b></td>\n";
print "<td valign=middle>";
print &ui_textbox("netmask", ( $sub ? $sub->{'values'}->[2] : "" ), 25);
print "</td>";
print "</tr>";

@range = $sub ? &find("range", $sub->{'members'}) : ();
print "<tr><td valign=middle><b>$text{'esub_arange'}</b></td><td valign=middle colspan=3>\n";
for($i=0; $i<=@range; $i++) {
	$r = $range[$i];
	my $dyn = ($r->{'values'}->[0] eq "dynamic-bootp");
    print &ui_textbox("range_low_".$i, $r->{'values'}->[$dyn], 15);
    print "&nbsp;-&nbsp;";
    print &ui_textbox("range_hi_".$i, $r->{'values'}->[$dyn+1], 15);
    print "&nbsp;";
    print &ui_checkbox("range_dyn_".$i, 1, $text{'esub_dbooptpq'}, ($dyn ? 1 : 0 ) );
	}
print "</td></tr>\n";

if (!defined($in{'ret'})) {
	print "<tr><td valign=middle><b>$text{'esub_shnet'}</b></td>\n";
	print "<td valign=middle>";
	my @shn;
	push(@shn, [ "", "&lt;$text{'esub_none'}&gt;" ]);
	foreach $s (&find("shared-network", $conf)) {
	push(@shn, [ $s->{'index'}, ( &can('rw', \%access, $s) ? $s->{'values'}->[0] : "" ) ]);
	}
	print &ui_select("parent", $s_parent ? $s_parent->{'index'} : "", \@shn);
	print "</td>\n";
	}
else {
	print "<tr>";
    print "<td>".&ui_hidden("parent",$s_parent->{'index'})."&nbsp;</td><td>&nbsp;</td>\n";
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

print "<tr><td valign=top><b>$text{'esub_hosts'}</b></td>\n";
print "<td valign=top>";
my @esub_hosts_sel;
foreach $h (@host) {
	next if !&can('r', \%access, $h);
    push(@esub_hosts_sel, [$h->{'index'}.",".$insubn{$h}, $h->{'values'}->[0], ( (!$in{'new'}) && $insubn{$h} eq $sub->{'index'} ? "selected" : "" ) ] );
	}
print &ui_select("hosts", undef, \@esub_hosts_sel, 3, 1);
print "</td>\n";

print "<td valign=top><b>$text{'esub_groups'}</b></td>\n";
print "<td valign=top>";
my @esub_groups_sel;
foreach $g (@group) {
	my $gm = 0;
	next if !&can('r', \%access, $g);
	foreach $h (@{$g->{'members'}}) {
		if ($h->{'name'} eq "host") { $gm++; }
		}
    push(@esub_groups_sel, [$g->{'index'}.",".$insubn{$g}, &group_name($gm, $g), ( (!$in{'new'}) && $insubn{$g} eq $sub->{'index'} ? "selected" : "" ) ] );
	}
print &ui_select("groups", undef, \@esub_groups_sel, 3, 1);
print "</td>\n";

if (!$in{'new'}) {
	# inaccessible hosts in this subnet
	foreach $h (@host) {
		if (!&can('r', \%access, $h) && $insubn{$h} eq $sub->{'index'}) {
            print &ui_hidden("hosts","$h->{'index'},$sub->{'index'}");
			}
		}
	# inaccessible groups in this subnet
	foreach $g (@group) {
		if (!&can('r', \%access, $g) && $insubn{$g} eq $sub->{'index'}) {
            print &ui_hidden("groups","$g->{'index'},$sub->{'index'}");
			}
		}
	}

print &ui_table_end();
print &ui_hidden("sidx", $in{'sidx'});

if (!$in{'new'}) {
	# Show buttons for existing subnet
    print &ui_hidden("idx", $in{'idx'});
	print "<table width=100%><tr>\n";
	print "<td>";
    print &ui_submit($text{'save'}) if &can('rw', \%access, $sub);  
    print "</td>";
	print "<td align=center>";
    print &ui_submit( (&can('rw', \%access, $sub) ? $text{'butt_eco'} : $text{'butt_vco'} ), "options");
	print "</td>";
	if ($access{'r_leases'}) {
		print "<td align=center>";
        print &ui_submit($text{'butt_leases'},"leases");
        print "</td>";
		}
	print "<td align=right>";
    print &ui_submit($text{'delete'}, "delete") if &can('rw', \%access, $sub, 1);
    print "</td>";
	print "</tr></table>\n";
    print &ui_link("edit_host.cgi?new=1&sidx=$in{'sidx'}&uidx=$in{'idx'}&ret=subnet", $text{'index_addhst'})."&nbsp;&nbsp;" if &can('rw', \%access, $sub);
    print &ui_link("edit_group.cgi?new=1&sidx=$in{'sidx'}&uidx=$in{'idx'}&ret=subnet", $text{'index_addhstg'}) if &can('rw', \%access, $sub);
	}
else {
	# Show create button for new subnet
    print &ui_hidden("new", "1");
    print "<br>";
    print &ui_submit($text{'create'});
	}

if ($config{'dhcpd_version'} >= 3 && !$in{'new'}) {
	# Display address pools
	print &ui_hr();
	print &ui_subheading($text{'esub_pools'});
	my $pn = 1;
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
    print &ui_link("edit_pool.cgi?uidx=$in{'idx'}&sidx=$in{'sidx'}&new=1",$text{'esub_pooladd'}); 
	}

print &ui_form_end();
print "<br>";
if ($in{'ret'} eq "shared") {
	&ui_print_footer("edit_shared.cgi?idx=$in{'sidx'}", $text{'esub_retshar'});
	}
else {
	&ui_print_footer("", $text{'esub_return'});
	}

