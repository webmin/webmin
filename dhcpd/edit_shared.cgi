#!/usr/local/bin/perl
# edit_shared.cgi
# Edit or create a shared network

require './dhcpd-lib.pl';
require './params-lib.pl';
&ReadParse();
$conf = &get_config();
($par, $sha) = &get_branch('sha');
$sconf = $sha->{'members'};

# check acls
%access = &get_module_acl();
&error_setup($text{'eacl_aviol'});
if ($in{'new'}  ) {
	&error("$text{'eacl_np'} $text{'eacl_pin'}")
		unless &can('c', \%access, $sha) && &can('rw', \%access, $par);
	}
else {
	&error("$text{'eacl_np'} $text{'eacl_psn'}")
		if !&can('r', \%access, $sha);
	}

# display
&ui_print_header(undef, $in{'new'} ? $text{'esh_crheader'} : $text{'esh_eheader'}, "");

print "<form action=save_shared.cgi method=post>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'esh_tabhdr'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'esh_desc'}</b></td>\n";
printf "<td colspan=3><input name=desc size=60 value='%s'></td> </tr>\n",
	$sha ? &html_escape($sha->{'comment'}) : "";

print "<tr> <td><b>$text{'esh_netname'}</b></td>\n";
printf "<td><input name=name size=15 value=\"%s\"></td>\n",
	$sha ? $sha->{'values'}->[0] : "";

&display_params($sconf, "shared-network");

print "<tr> <td colspan=4> <table border=0 width=100%>\n";
foreach $h (&find("host", $conf)) {
	push(@host, $h) if &can('r', \%access, $h);
	}
foreach $g (&find("group", $conf)) {
	push(@group, $g) if &can('r', \%access, $g);
	}
foreach $s (&find("subnet", $conf)) {
	push(@subn, $s) if &can('r', \%access, $s);
	}
foreach $sh (&find("shared-network", $conf)) {
	foreach $h (&find("host", $sh->{'members'})) {
		push(@host, $h);
# if &can('r', \%access, $h);
		$inshar{$h} = $sh->{'index'};
		}
	foreach $g (&find("group", $sh->{'members'})) {
		push(@group, $g);
# if &can('r', \%access, $g);
		$inshar{$g} = $sh->{'index'};
		}
	foreach $s (&find("subnet", $sh->{'members'})) {
		push(@subn, $s);
# if &can('r', \%access, $s);
		$inshar{$s} = $sh->{'index'};
		}
	}
@host = sort { $a->{'values'}->[0] cmp $b->{'values'}->[0] } @host;
# @group = sort { @{$a->{'members'}} <=> @{$b->{'members'}} } @group;
@subn = sort { $a->{'values'}->[0] cmp $b->{'values'}->[0] } @subn;

print "<td valign=top align=right><b>$text{'esh_hosts'}</b></td>\n";
print "<td><select name=hosts size=3 multiple>\n";
foreach $h (@host) {
	next if !&can('r', \%access, $h);
	printf "<option value=\"%s,%s\" %s>%s</option>\n",
		$h->{'index'}, $inshar{$h},
		(!$in{'new'}) && $inshar{$h} eq $sha->{'index'} ? "selected" : "",
		$h->{'values'}->[0];
	}
print "</select></td>\n";

print "<td valign=top align=right><b>$text{'esh_groups'}</b></td>\n";
print "<td><select name=groups size=3 multiple>\n";
foreach $g (@group) {
	local $gm = 0;
	next if !&can('r', \%access, $g);
	foreach $h (@{$g->{'members'}}) {
		if ($h->{'name'} eq "host") { $gm++; }
		}
	printf "<option value=\"%s,%s\" %s>%s</option>\n",
		$g->{'index'}, $inshar{$g},
		(!$in{'new'}) && $inshar{$g} eq $sha->{'index'} ? "selected" : "",
		&group_name($gm, $g);
	}
print "</select></td>\n";

print "<td valign=top align=right><b>$text{'esh_subn'}</b></td>\n";
print "<td><select name=subnets size=3 multiple>\n";
foreach $s (@subn) {
	next if !&can('r', \%access, $s);
	printf "<option value=\"%s,%s\" %s>%s</option>\n",
		$s->{'index'}, $inshar{$s},
		(!$in{'new'}) && $inshar{$s} eq $sha->{'index'} ? "selected" : "",
		$s->{'values'}->[0];
	}
print "</select></td>\n";

if (!$in{'new'}) {
	# inaccessible hosts in this shared network
	foreach $h (@host) {
		if (!&can('r', \%access, $h) && $inshar{$h} eq $sha->{'index'}) {
			print "<input name=hosts value=\"$h->{'index'},$sha->{'index'}\" type=hidden>\n";
			}
		}
	# inaccessible groups in this shared network
	foreach $g (@group) {
		if (!&can('r', \%access, $g) && $inshar{$g} eq $sha->{'index'}) {
			print "<input name=groups value=\"$g->{'index'},$sha->{'index'}\" type=hidden>\n";
			}
		}
	# inaccessible subnets in this shared network
	foreach $s (@subn) {
		if (!&can('r', \%access, $s) && $inshar{$s} eq $sha->{'index'}) {
			print "<input name=subnets value=\"$s->{'index'},$sha->{'index'}\" type=hidden>\n";
			}
		}
	}
print "</table></td></tr>\n";

print "</table></td></tr></table>\n";
if (!$in{'new'}) {
	print "<input type=hidden name=idx value=\"$in{'idx'}\">\n";
	print "<table width=100%><tr>\n";
	print "<td><input type=submit value=\"$text{'save'}\"></td>\n"
		if &can('rw', \%access, $sha);
	print "<td align=center><input type=submit name=options value=\"",
          &can('rw', \%access, $sha) ? $text{'butt_eco'} : $text{'butt_vco'},
	      "\"></td>\n";		  
	print "<td align=right><input type=submit name=delete ",
	      "value=\"$text{'delete'}\"></td>\n" 
		  if &can('rw', \%access, $sha, 1);
	print "</tr></table>\n";
	print "<a href=\"edit_host.cgi?new=1&sidx=$in{'idx'}"
		."&ret=shared\">$text{'index_addhst'}</a>&nbsp;&nbsp;\n"
			if &can('rw', \%access, $sha);
	print "<a href=\"edit_group.cgi?new=1&sidx=$in{'idx'}"
		."&ret=shared\">$text{'index_addhstg'}</a>&nbsp;&nbsp;\n"
			if &can('rw', \%access, $sha);
	print "<a href=\"edit_subnet.cgi?new=1&sidx=$in{'idx'}"
		."&ret=shared\">$text{'index_addsub'}</a><p>\n"
			if &can('rw', \%access, $sha);
	}
else {
	print "<input type=hidden name=new value=1>\n";
	print "<input type=submit value=\"$text{'create'}\">\n";
	}

if ($config{'dhcpd_version'} >= 3 && !$in{'new'}) {
	# Display address pools
	print &ui_hr();
	print &ui_subheading($text{'esh_pools'});
	local $pn = 1;
	foreach $p (&find('pool', $sconf)) {
		push(@links, "edit_pool.cgi?uidx=$in{'idx'}&idx=$p->{'index'}");
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
	print "<a href='edit_pool.cgi?uidx=$in{'idx'}&new=1'>",
	      "$text{'esub_pooladd'}</a><br>\n";
	}

print "</form>\n";
&ui_print_footer("", $text{'esh_return'});

