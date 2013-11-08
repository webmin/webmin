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

print "<form action=save_group.cgi method=post>\n";
print "<input name=ret value=\"$in{'ret'}\" type=hidden>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'egroup_tblhdr'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'egroup_desc'}</b></td>\n";
printf "<td colspan=3><input name=desc size=60 value='%s'></td> </tr>\n",
	&html_escape($group->{'comment'});

$rws = "rowspan=2" if (defined($in{'ret'}));
print "<tr> <td $rws valign=top><b>$text{'egroup_hosts'}</b></td>\n";
print "<td $rws><select name=hosts size=5 multiple>\n";
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
foreach $h (@host) {
	next if !&can('r', \%access, $h);
	printf "<option value=\"%s,%s\" %s>%s</option>\n",
		$h->{'index'}, $ingroup{$h},
		(!$in{'new'}) && $ingroup{$h} eq $group->{'index'} ? "selected" : "",
		$h->{'values'}->[0];
	}
print "</select></td>\n";

if (!$in{'new'}) {
	# inaccessible hosts in this group
	foreach $h (@host) {
		if (!&can('r', \%access, $h) && $ingroup{$h} eq $group->{'index'}) {
			print "<input name=hosts value=\"$h->{'index'},$group->{'index'}\" type=hidden>\n";
			}
		}
	}

$assign = $in{'uidx'} ne "" ? "2" :
	$in{'sidx'} ne "" ? "1" : "0";
if (!defined($in{'ret'})) {
	local @labels = ( $text{'ehost_toplevel'}, $text{'ehost_inshared'},
			  $text{'ehost_insubnet'} );
	print "<td colspan=2><table><tr>";
	print "<td colspan=2>$text{'ehost_nojavascr'}</td></tr>\n<tr>" if ($in{'assign'});
	print "<td valign=top><b>$text{'egroup_assign'}</b><br>\n";
	if ($in{'assign'}) {
		$assign = $in{'assign'};
		print "$labels[$assign]</td>\n";
		print "<input name=assign type=hidden value=$assign>\n";
		print "<input name=jsquirk type=hidden value=1>\n";
		}
	else {
		print "<select name=assign onChange='setparent(0)'>\n";
		for ($i = 0; $i <= 2; $i++) {
			printf "<option value=$i %s>%s</option>\n",
				$assign == $i ? "selected" : "",
				$labels[$i];
			}
		print "</select></td>\n";
		}
	print "<td><select name=parent size=5 width=120>\n";
	if ($assign == 2) {
		$iu = 0;
		foreach $u (@subn) {
			printf "<option value=\"%s\" %s>%s</option>\n",
				defined($shared{$u}) ? "$shared{$u},$u->{'index'}" : $u->{'index'},
				$iu == $sel_parent ? "selected" : "",
				$subn_desc[$iu]
					if &can('rw', \%access, $u);
			$iu ++;
			}
		}
	elsif ($assign == 1) {
		$is = 0;
		foreach $s (@shar) {
			printf "<option value=\"%s\" %s>%s</option>\n",
				$s->{'index'},
				$is == $sel_parent ? "selected" : "",
				$shar_desc[$is]
					if &can('rw', \%access, $s);
			$is ++;
			}
		}
	print "</select></td></tr>\n";
	print "</table></td>\n";
	print "</tr> <tr>\n";
	}
else {
	print "<input name=assign type=hidden value=$assign>\n",
	print "<input name=parent type=hidden value=$currpar>\n";
	}

print &choice_input($text{'egroup_nchoice'}, "use-host-decl-names",
	$gconf, " $text{'yes'}", "on", " $text{'no'}", "off", " $text{'default'}", "");

print "</tr> <tr>\n" if (defined($in{'ret'}));
&display_params($gconf, "group");

print "</table></td></tr></table>\n";
print "<input type=hidden name=sidx value=\"$in{'sidx'}\">\n";
print "<input type=hidden name=uidx value=\"$in{'uidx'}\">\n";
if (!$in{'new'}) {
	print "<input type=hidden name=idx value=\"$in{'idx'}\">\n";
	print "<table width=100%><tr>\n";
	print "<td><input type=submit value=\"$text{'save'}\"></td>\n"
		if &can('rw', \%access, $group);
	print "<td align=center><input type=submit name=options value=\"",
          &can('rw', \%access, $group) ? $text{'butt_eco'} : $text{'butt_vco'},
	      "\"></td>\n";		  
	print "<td align=right><input type=submit name=delete ",
	      "value=\"$text{'delete'}\"></td>\n" 
		  if &can('rw', \%access, $group, 1);
	print "</tr></table>\n";
	print "<a href=\"edit_host.cgi?new=1&sidx=".$in{'sidx'}."&uidx=".$in{'uidx'}
		."&gidx=".$in{'idx'}."&ret=group\">"
		.$text{'index_addhst'}."</a><p>\n" if &can('rw', \%access, $group);
	}
else {
	print "<input type=hidden name=new value=1>\n";
	print "<input type=submit value=\"$text{'create'}\">\n";
	}
print "</form>\n";
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
