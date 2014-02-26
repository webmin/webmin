#!/usr/local/bin/perl
# edit_group.cgi
# Edit or create a group

require './dhcpd-lib.pl';
require './params-lib.pl';
&ReadParse();
$conf = &get_config();
($par, $group) = get_branch('grp');
$gconf = $group->{'members'};
$mems = $par->{'members'};

# check acls
%access = &get_module_acl();
&error_setup($text{'eacl_aviol'});
if ($in{'new'}) {
	&error("$text{'eacl_np'} $text{'eacl_pig'}")
		unless &can('c', \%access, $group) && &can('rw', \%access, $par);
	}
else {
	&error("$text{'eacl_np'} $text{'eacl_psg'}")
		if !&can('r', \%access, $group);
	}
# per hosts acl check is below

# display
if ($in{'uidx'} ne '') {
	local $s = $in{'sidx'} eq '' ? $conf->[$in{'uidx'}] :
		   $conf->[$in{'sidx'}]->{'members'}->[$in{'uidx'}];
	$desc = &text('ehost_subnet', $s->{'values'}->[0], $s->{'values'}->[2]);
	}
elsif ($in{'sidx'} ne '') {
	local $s = $conf->[$in{'sidx'}];
	$desc = &text('ehost_shared', $s->{'values'}->[0]);
	}
&ui_print_header($desc, $in{'new'} ? $text{'egroup_crheader'} : $text{'egroup_eheader'}, "");

@shar = &find("shared-network", $conf);
@subn = &find("subnet", $conf);
$iu = 0; $is = 0;
foreach $u (@subn) {
	push(@subn_desc, $u->{'values'}->[0]);
	$script2 .= "parent.options[$iu] = "
		."new Option(\"$subn_desc[$iu]\", $iu)\n"
		."parent.options[$iu].value = "
		."new String(\"$u->{'index'}\")\n"
			if &can('rw', \%access, $u);
	if ($in{'sidx'} eq '' && $in{'uidx'} eq $u->{'index'}) {
		$sel_parent = $iu;
		$currpar = "$u->{'index'}";
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
	if ($in{'sidx'} eq $s->{'index'} && $in{'uidx'} eq '') {
		$sel_parent = $is;
		$currpar = "$s->{'index'}";
		}
	$is ++;
	foreach $u (&find("subnet", $s->{'members'})) {
		push(@subn, $u);
		push(@subn_desc, "$u->{'values'}->[0] $text{'ehost_in'} $s->{'values'}->[0]");
		$shared{$u} = $s->{'index'};
		$script2 .= "parent.options[$iu] = "
			."new Option(\"$subn_desc[$iu]\", $iu)\n"
			."parent.options[$iu].value = "
			."new String(\"$s->{'index'},$u->{'index'}\")\n"
				if &can('rw', \%access, $u);
		if ($in{'sidx'} eq $s->{'index'} && $in{'uidx'} eq $u->{'index'}) {
			$sel_parent = $iu;
			$currpar = "$s->{'index'},$u->{'index'}";
			}
		$iu ++;
		}
	}

print &ui_form_start("save_group.cgi", "post");
print &ui_hidden("ret",$in{'ret'});
print &ui_table_start($text{'egroup_tblhdr'}, "width=100%", 4);

print "<tr><td valign=middle><b>$text{'egroup_desc'}</b></td>\n";
print "<td valign=middle colspan=3>";
print &ui_textbox("desc", &html_escape($group->{'comment'}), 60);
print "</td>";
print "</tr>";

$rws = (defined($in{'ret'}) ? " rowspan=2 " : " ");
print "<tr><td".$rws."valign=top><b>$text{'egroup_hosts'}</b></td>\n";
print "<td".$rws."valign=top>";
foreach $h (&find("host", $mems)) {
	push(@host, $h);
# if &can('r', \%access, $h);
	}
foreach $g (&find("group", $mems)) {
	foreach $h (&find("host", $g->{'members'})) {
		push(@host, $h);
# if &can('r', \%access, $h);
		$ingroup{$h} = $g->{'index'};
		}
	}
@host = sort { $a->{'values'}->[0] cmp $b->{'values'}->[0] } @host;
my @hosts_sel;
foreach $h (@host) {
	next if !&can('r', \%access, $h);
    push(@hosts_sel, ["$h->{'index'},$ingroup{$h}", $h->{'values'}->[0], ((!$in{'new'}) && $ingroup{$h} eq $group->{'index'} ? "selected" : "") ] );
	}
print &ui_select("hosts", undef, \@hosts_sel, 5, 1);
print "</td>\n";

if (!$in{'new'}) {
	# inaccessible hosts in this group
	foreach $h (@host) {
		if (!&can('r', \%access, $h) && $ingroup{$h} eq $group->{'index'}) {
            print &ui_hidden("hosts","$h->{'index'},$group->{'index'}");
			}
		}
	}

$assign = $in{'uidx'} ne "" ? "2" :
	$in{'sidx'} ne "" ? "1" : "0";
if (!defined($in{'ret'})) {
	my @labels = ( $text{'ehost_toplevel'}, $text{'ehost_inshared'},
			  $text{'ehost_insubnet'} );
	print "<td colspan=2><table><tr>";
	print "<td colspan=2>$text{'ehost_nojavascr'}</td></tr>\n<tr>" if ($in{'assign'});
	print "<td valign=top><b>$text{'egroup_assign'}</b><br>\n";
	if ($in{'assign'}) {
		$assign = $in{'assign'};
		print "$labels[$assign]</td>\n";
        print &ui_hidden("assign",$assign);
        print &ui_hidden("jsquirk",1);
		}
	else {
        my @assign_sel;
		for ($i = 0; $i <= 2; $i++) {
            push(@assign_sel, [$i, $labels[$i], ( $assign == $i ? "selected" : "" ) ]); 
			}
        print &ui_select("assign", undef, \@assign_sel, 1, undef, undef, undef, "onChange='setparent(0)'" );
		print "</td>";
		}
	print "<td>";
    my @parent_sel;
	if ($assign == 2) {
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

print &choice_input($text{'egroup_nchoice'}, "use-host-decl-names",
	$gconf, " $text{'yes'}", "on", " $text{'no'}", "off", " $text{'default'}", "");

print "</tr> <tr>\n" if (defined($in{'ret'}));
&display_params($gconf, "group");

print "</table>";
print &ui_table_end();

print &ui_hidden("sidx",$in{'sidx'});
print &ui_hidden("uidx",$in{'uidx'});

if (!$in{'new'}) {
    print &ui_hidden("idx",$in{'idx'});
	print "<table width=100%><tr>\n";
    print "<td>".&ui_submit($text{'save'})."</td>" if &can('rw', \%access, $group);
    print "<td align=center>".&ui_submit(( &can('rw', \%access, $group) ? $text{'butt_eco'} : $text{'butt_vco'} ),"options")."</td>";
    print "<td align=right>".&ui_submit($text{'delete'},"delete")."</td>" if &can('rw', \%access, $group, 1);
	print "</tr></table>\n";
    print &ui_link("edit_host.cgi?new=1&sidx=".$in{'sidx'}."&uidx=".$in{'uidx'}."&gidx=".$in{'idx'}."&ret=group",$text{'index_addhst'}) if &can('rw', \%access, $group);
	}
else {
    print &ui_hidden("new",1);
    print &ui_submit($text{'create'});
	}
print &ui_form_end();
print &script_fn() if (!defined($in{'ret'}));
if ($in{'ret'} eq "subnet") {
	&ui_print_footer("edit_subnet.cgi?sidx=$in{'sidx'}&idx=$in{'uidx'}",
		$text{'egroup_retsubn'});
	}
elsif ($in{'ret'} eq "shared") {
	&ui_print_footer("edit_shared.cgi?idx=$in{'sidx'}", $text{'egroup_retshar'});
	}
else {
	&ui_print_footer($ret, $text{'egroup_return'});
	}

sub script_fn
{
return <<EOF
<script>
function setparent(sel)
{
var idx = document.forms[0].assign.selectedIndex;
var v = document.forms[0].assign.options[idx].value;
var vv = v.split(";");
var parent = document.forms[0].parent;
parent.length = 0;

if (v==1) {
$script1
}
if (v==2) {
$script2
}
if (parent.length > 0) {
	parent.options[sel].selected = true;
	}
}
setparent($sel_parent);
</script>
EOF

}
