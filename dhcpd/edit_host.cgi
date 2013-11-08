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
	local $s = $in{'sidx'} eq '' ? $conf->[$in{'uidx'}] :
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

print "<form action=save_host.cgi method=post>\n";
print "<input name=ret value=\"$in{'ret'}\" type=hidden>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'ehost_tabhdr'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'ehost_desc'}</b></td>\n";
printf "<td colspan=3><input name=desc size=60 value='%s'></td> </tr>\n",
	&html_escape($host->{'comment'});

print "<tr> <td><b>$text{'ehost_hname'}</b></td>\n";
printf "<td><input name=name size=20 value=\"%s\"></td>\n",
	$host ? $host->{'values'}->[0] : "";
$assign = $in{'gidx'} ne "" ? "3" :
	$in{'uidx'} ne "" ? "2" :
	$in{'sidx'} ne "" ? "1" : "0";
if (!defined($in{'ret'})) {
	local @labels = ( $text{'ehost_toplevel'}, $text{'ehost_inshared'},
			  $text{'ehost_insubnet'}, $text{'ehost_ingroup'} );
	print "<td colspan=2 rowspan=2><table><tr>";
	print "<td colspan=2>$text{'ehost_nojavascr'}</td></tr>\n<tr>" if ($in{'assign'});
	print "<td valign=top><b>$text{'ehost_assign'}</b><br>\n";
	if ($in{'assign'}) {
		$assign = $in{'assign'};
		print "$labels[$assign]</td>\n";
		print "<input name=assign type=hidden value=$assign>\n";
		print "<input name=jsquirk type=hidden value=1>\n";
		}
	else {
		print "<select name=assign onChange='setparent(0)'>\n";
		for ($i = 0; $i <= 3; $i++) {
			printf "<option value=$i %s>%s</option>\n",
				$assign == $i ? "selected" : "",
				$labels[$i];
			}
		print "</select></td>\n";
		}
	print "<td><select name=parent size=5 width=120>\n";
	if ($assign == 3) {
		$ig = 0;
		foreach $g (@group) {
			printf "<option value=\"%s\" %s>%s</option>\n",
				(defined($shared{$g}) ? "$shared{$g}," : "").
				(defined($subnet{$g}) ? "$subnet{$g}," : "").
				$g->{'index'},
				$ig == $sel_parent ? "selected" : "",
				$group_desc[$ig]
					if &can('rw', \%access, $g);
			$ig ++;
			}
		}
	elsif ($assign == 2) {
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
	print "<input name=assign type=hidden value=$assign>\n";
	print "<input name=parent type=hidden value=$currpar>\n";
	}

$hard = $hconf ? &find("hardware", $hconf) : undef;
print "<td><b>$text{'ehost_hwaddr'}</b></td>\n";
print "<td nowrap><select name=hardware_type>\n";
printf "<option %s>ethernet</option>\n",
	$hard && $hard->{'values'}->[0] eq "ethernet" ? "selected" : "";
printf "<option %s>token-ring</option>\n",
	$hard && $hard->{'values'}->[0] eq "token-ring" ? "selected" : "";
printf "<option %s>fddi</option>\n",
	$hard && $hard->{'values'}->[0] eq "fddi" ? "selected" : "";
print "</select>";
printf "<input name=hardware size=18 value=\"%s\"></td> </tr>\n",
	$hard ? $hard->{'values'}->[1] : "";

$fixed = $host ? &find("fixed-address", $hconf) : "";
print "<tr> <td><b>$text{'ehost_fixedip'}</b></td> <td>\n";
printf "<input name=fixed-address size=20 value=\"%s\"></td>\n",
	$fixed ? join(" ", grep { $_ ne "," } @{$fixed->{'values'}}) : "";

&display_params($hconf, "host");

print "</table></td></tr></table>\n";
print "<input type=hidden name=gidx value=\"$in{'gidx'}\">\n";
print "<input type=hidden name=uidx value=\"$in{'uidx'}\">\n";
print "<input type=hidden name=sidx value=\"$in{'sidx'}\">\n";
if (!$in{'new'}) {
	print "<input type=hidden name=idx value=\"$in{'idx'}\">\n";
	print "<table width=100%><tr>\n";
	print "<td><input type=submit value=\"$text{'save'}\"></td>\n"
		if &can('rw', \%access, $host);
	print "<td align=center><input type=submit name=options value=\"",
          &can('rw', \%access, $host) ? $text{'butt_eco'} : $text{'butt_vco'},
	      "\"></td>\n";		  
	print "<td align=right><input type=submit name=delete ",
	      "value=\"$text{'delete'}\"></td>\n" 
		  if &can('rw', \%access, $host, 1);
	print "</tr></table>\n";
	}
else {
	print "<input type=hidden name=new value=1>\n";
	print "<input type=submit value=\"$text{'butt_create'}\">\n";
	}
print "</form>\n";
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
