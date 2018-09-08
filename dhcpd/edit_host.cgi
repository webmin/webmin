#!/usr/local/bin/perl
# edit_host.cgi
# Edit or create a host

require './dhcpd-lib.pl';
require './params-lib.pl';
&ReadParse();
$conf = &get_config();
($par, $host) = &get_branch('hst');
$hconf = $host->{'members'};

# check acls
%access = &get_module_acl();
&error_setup($text{'eacl_aviol'});
if ($in{'new'}  ) {
	&error("$text{'eacl_np'} $text{'eacl_pih'}")
		unless &can('c', \%access, $host) && &can('rw', \%access, $par);
	}
else {
	&error("$text{'eacl_np'} $text{'eacl_psh'}")
		if !&can('r', \%access, $host);
	}

# display
if ($in{'uidx'} ne '') {
	my $s = $in{'sidx'} eq '' ? $conf->[$in{'uidx'}] :
		   $conf->[$in{'sidx'}]->{'members'}->[$in{'uidx'}];
	$desc = &text('ehost_subnet', $s->{'values'}->[0], $s->{'values'}->[2]);
	}
elsif ($in{'sidx'} ne '') {
	local $s = $conf->[$in{'sidx'}];
	$desc = &text('ehost_shared', $s->{'values'}->[0]);
	}
&ui_print_header($desc, $in{'new'} ? $text{'ehost_crheader'} : $text{'ehost_eheader'}, "");

@shar = &find("shared-network", $conf);
@subn = &find("subnet", $conf);
@group = &find("group", $conf);
$iu = 0; $is = 0; $ig = 0;
foreach $g (@group) {
	$gm = 0;
	foreach $h (&find("host", $g->{'members'})) { $gm++; };
	push(@group_desc, &group_name($gm, $g));
	$group_desc[$#group_desc-1] =~ s/&nbsp;/ /g;
	$script3 .= "parent.options[$ig] = "
		."new Option(\"$group_desc[$ig]\", $ig)\n"
		."parent.options[$ig].value = "
		."new String(\"$g->{'index'}\")\n"
			if &can('rw', \%access, $g);
	if ($in{'sidx'} eq '' && $in{'uidx'} eq '' && $in{'gidx'} eq $g->{'index'}) {
		$sel_parent = $ig;
		$currpar = "$g->{'index'}";
		}
	$ig ++;
	}
foreach $u (@subn) {
	push(@subn_desc, $u->{'values'}->[0]);
	$script2 .= "parent.options[$iu] = "
		."new Option(\"$subn_desc[$iu]\", $iu)\n"
		."parent.options[$iu].value = "
		."new String(\"$u->{'index'}\")\n"
			if &can('rw', \%access, $u);
	if ($in{'sidx'} eq '' && $in{'uidx'} eq $u->{'index'} && $in{'gidx'} eq '') {
		$sel_parent = $iu;
		$currpar = "$u->{'index'}";
		}
	foreach $g (&find("group", $u->{'members'})) {
		push(@group, $g);
		$gm = 0;
		foreach $h (&find("host", $g->{'members'})) { $gm ++; };
		push(@group_desc, &group_name($gm, $g).
				  " $text{'ehost_in'} $u->{'values'}->[0]");
		$group_desc[$#group_desc-1] =~ s/&nbsp;/ /g;
		$subnet{$g} = $u->{'index'};
		$script3 .= "parent.options[$ig] = "
			."new Option(\"$group_desc[$ig]\", $ig)\n"
			."parent.options[$ig].value = "
			."new String(\"$u->{'index'},$g->{'index'}\")\n"
				if &can('rw', \%access, $g);
		if ($in{'sidx'} eq '' && $in{'uidx'} eq $u->{'index'} && $in{'gidx'} eq $g->{'index'}) {
			$sel_parent = $ig;
			$currpar = "$u->{'index'},$g->{'index'}";
			}
		$ig ++;
		}
	$iu ++;
	}
foreach $s (@shar) {
	push(@shar_desc, $s->{'values'}->[0]);
	$script1 .= "parent.options[$is] = "
		."new Option(\"$shar_desc[$is]\", $is)\n"
		."parent.options[$is].value = "
		."new String(\"$s->{'index'}\")\n"
			if &can('rw', \%access, $s);
	if ($in{'sidx'} eq $s->{'index'} && $in{'uidx'} eq '' && $in{'gidx'} eq '') {
		$sel_parent = $is;
		$currpar = "$s->{'index'}";
		}
	foreach $g (&find("group", $s->{'members'})) {
		push(@group, $g);
		$gm = 0;
		foreach $h (&find("host", $g->{'members'})) { $gm ++; };
		push(@group_desc, &group_name($gm, $g).
				  " $text{'ehost_in'} $s->{'values'}->[0]");
		$group_desc[$#group_desc-1] =~ s/&nbsp;/ /g;
		$shared{$g} = $s->{'index'};
		$script3 .= "parent.options[$ig] = "
			."new Option(\"$group_desc[$ig]\", $ig)\n"
			."parent.options[$ig].value = "
			."new String(\"$s->{'index'},$g->{'index'}\")\n"
				if &can('rw', \%access, $g);
		if ($in{'sidx'} eq $s->{'index'} && $in{'uidx'} eq '' && $in{'gidx'} eq $g->{'index'}) {
			$sel_parent = $ig;
			$currpar = "$s->{'index'},$g->{'index'}";
			}
		$ig ++;
		}
	foreach $u (&find("subnet", $s->{'members'})) {
		push(@subn, $u);
		push(@subn_desc, "$u->{'values'}->[0] $text{'ehost_in'} $s->{'values'}->[0]");
		$shared{$u} = $s->{'index'};
		$script2 .= "parent.options[$iu] = "
			."new Option(\"$subn_desc[$iu]\", $iu)\n"
			."parent.options[$iu].value = "
			."new String(\"$s->{'index'},$u->{'index'}\")\n"
				if &can('rw', \%access, $u);
		if ($in{'sidx'} eq $s->{'index'} && $in{'uidx'} eq $u->{'index'} && $in{'gidx'} eq '') {
			$sel_parent = $iu;
			$currpar = "$s->{'index'},$u->{'index'}";
			}
		foreach $g (&find("group", $u->{'members'})) {
			push(@group, $g);
			$gm = 0;
			foreach $h (&find("host", $g->{'members'})) { $gm ++; };
			push(@group_desc, &group_name($gm, $g).
			  " $text{'ehost_in'} $u->{'values'}->[0] ".
			  "$text{'ehost_in'} $s->{'values'}->[0]");
			$group_desc[$#group_desc-1] =~ s/&nbsp;/ /g;
			$shared{$g} = $s->{'index'};
			$subnet{$g} = $u->{'index'};
			$script3 .= "parent.options[$ig] = "
				."new Option(\"$group_desc[$ig]\", $ig)\n"
				."parent.options[$ig].value = "
				."new String(\"$s->{'index'},$u->{'index'},$g->{'index'}\")\n"
					if &can('rw', \%access, $g);
			if ($in{'sidx'} eq $s->{'index'} && $in{'uidx'} eq $u->{'index'} && $in{'gidx'} eq $g->{'index'}) {
				$sel_parent = $ig;
				$currpar = "$s->{'index'},$u->{'index'},$g->{'index'}";
				}
			$ig ++;
			}
		$iu ++;
		}
	$is ++;
	}
print &ui_form_start("save_host.cgi", "post");
print &ui_hidden("ret",$in{'ret'});
print &ui_table_start($text{'ehost_tabhdr'}, "width=100%", 4);

print "<tr><td valign=middle><b>$text{'ehost_desc'}</b></td>\n";
print "<td valign=middle colspan=3>";
print &ui_textbox("desc", &html_escape($host->{'comment'}), 60);
print "</td>";
print "</tr>";

print "<tr><td valign=middle><b>$text{'ehost_hname'}</b></td>\n";
print "<td valign=middle>";
print &ui_textbox("name", ( $host ? $host->{'values'}->[0] : "" ), 20);
print "</td>\n";

$assign = $in{'gidx'} ne "" ? "3" :
	$in{'uidx'} ne "" ? "2" :
	$in{'sidx'} ne "" ? "1" : "0";
if (!defined($in{'ret'})) {
	my @labels = ( $text{'ehost_toplevel'}, $text{'ehost_inshared'},
			  $text{'ehost_insubnet'}, $text{'ehost_ingroup'} );
	print "<td valign=top colspan=2 rowspan=2><table><tr>";
	print "<td colspan=2>$text{'ehost_nojavascr'}</td></tr>\n<tr>" if ($in{'assign'});
	print "<td valign=top><b>$text{'ehost_assign'}</b><br>\n";
	if ($in{'assign'}) {
		$assign = $in{'assign'};
		print "$labels[$assign]</td>\n";
        print &ui_hidden("assign",$assign);
        print &ui_hidden("jsquirk",1);
		}
	else {
        my @assign_sel;
		for ($i = 0; $i <= 3; $i++) {
            push(@assign_sel, [$i, $labels[$i], ( $assign == $i ? "selected" : "" ) ]); 
			}
        print &ui_select("assign", undef, \@assign_sel, 1, undef, undef, undef, "onChange='setparent(0)'" );
		print "</td>\n";
		}
	print "<td>";
    my @parent_sel;
	if ($assign == 3) {
		$ig = 0;
		foreach $g (@group) {
            my $val = (defined($shared{$g}) ? "$shared{$g}," : "").(defined($subnet{$g}) ? "$subnet{$g}," : "").$g->{'index'};
            my $txt = $group_desc[$ig] if &can('rw', \%access, $g);
            push(@parent_sel, [$val, $txt, ($ig == $sel_parent ? "selected" : "") ] );
			$ig++;
			}
		}
	elsif ($assign == 2) {
		$iu = 0;
		foreach $u (@subn) {
            my $val1 = defined($shared{$u}) ? "$shared{$u},$u->{'index'}" : $u->{'index'};
            my $txt1 = $subn_desc[$iu] if &can('rw', \%access, $u);
            push(@parent_sel, [$val1, $txt1, ($iu == $sel_parent ? "selected" : "") ] );
			$iu++;
			}
		}
	elsif ($assign == 1) {
		$is = 0;
		foreach $s (@shar) {
            my $txt2 = $shar_desc[$is] if &can('rw', \%access, $s);
            push(@parent_sel, [$s->{'index'}, $txt1, ($is == $sel_parent ? "selected" : "") ] );
			$is++;
			}
		}
    print &ui_select("parent", undef, \@parent_sel, 5, undef, undef, undef, "width=120");
	print "</td></tr>\n";
	print "</table></td>\n";
	print "</tr><tr>\n";
	}
else {
    print &ui_hidden("assign",$assign);
    print &ui_hidden("parent",$currpar);
	}

$hard = $hconf ? &find("hardware", $hconf) : undef;
print "<td valign=middle><b>$text{'ehost_hwaddr'}</b></td>\n";
print "<td valign=middle nowrap>";
my @hardware_type_sel;
my @hardware = ("ethernet","token-ring","fddi");
foreach my $hv (@hardware) {
    push(@hardware_type_sel, [$hv,$hv, ($hard && $hard->{'values'}->[0] eq $hv ? "selected" : "")] );
}
print &ui_select("hardware_type", undef, \@hardware_type_sel, 1);
print &ui_textbox("hardware", ( $hard ? $hard->{'values'}->[1] : "" ), 18);
print "</td></tr>\n";

$fixed = $host ? &find("fixed-address", $hconf) : "";
print "<tr><td><b>$text{'ehost_fixedip'}</b></td><td>\n";
print &ui_textbox("fixed-address", ( $fixed ? join(" ", grep { $_ ne "," } @{$fixed->{'values'}}) : "" ), 20);
print "</td>\n";

&display_params($hconf, "host");

print &ui_table_end();

print &ui_hidden("gidx",$in{'gidx'});
print &ui_hidden("uidx",$in{'uidx'});
print &ui_hidden("sidx",$in{'sidx'});

if (!$in{'new'}) {
    print &ui_hidden("idx",$in{'idx'});
	print "<table width=100%><tr>\n";
    print "<td>".&ui_submit($text{'save'})."</td>" if &can('rw', \%access, $host);
    print "<td align=center>".&ui_submit(( &can('rw', \%access, $host) ? $text{'butt_eco'} : $text{'butt_vco'} ),"options")."</td>";
    print "<td align=right>".&ui_submit($text{'delete'},"delete")."</td>" if &can('rw', \%access, $host, 1);
	print "</tr></table>\n";
	}
else {
    print &ui_hidden("new",1);
    print &ui_submit($text{'butt_create'});
	}

print &ui_form_end();

print &script_fn() if (!defined($in{'ret'}));
if ($in{'ret'} eq "group") {
	&ui_print_footer("edit_group.cgi?sidx=$in{'sidx'}&uidx=$in{'uidx'}&idx=$in{'gidx'}",
		$text{'ehost_retgroup'});
	}
elsif ($in{'ret'} eq "subnet") {
	&ui_print_footer("edit_subnet.cgi?sidx=$in{'sidx'}&idx=$in{'uidx'}",
		$text{'ehost_retsubn'});
	}
elsif ($in{'ret'} eq "shared") {
	&ui_print_footer("edit_shared.cgi?idx=$in{'sidx'}", $text{'ehost_retshar'});
	}
else {
	&ui_print_footer($ret, $text{'ehost_return'});
	}

sub script_fn
{
return <<EOF
<script type='text/javascript'>
function setparent(sel)
{
var idx = document.getElementsByName("assign")[0].selectedIndex;
var v = document.getElementsByName("assign")[0].options[idx].value;
var vv = v.split(";");
var parent = document.getElementsByName("parent")[0];
parent.length = 0;

if (v==1) {
$script1
}
if (v==2) {
$script2
}
if (v==3) {
$script3
}
if (parent.length > 0) {
	parent.options[sel].selected = true;
	}
}
setparent($sel_parent);
</script>
EOF

}

