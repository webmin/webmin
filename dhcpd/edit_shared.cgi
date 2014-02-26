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
print &ui_form_start("save_shared.cgi", "post");
print &ui_table_start($text{'esh_tabhdr'}, "width=100%", 4);

print "<tr><td valign=middle><b>$text{'esh_desc'}</b></td>\n";
print "<td valign=middle colspan=3>";
print &ui_textbox("desc", ( $sha ? &html_escape($sha->{'comment'}) : "" ), 60);
print "</td>";
print "</tr>";

print "<tr><td valign=middle><b>$text{'esh_netname'}</b></td>\n";
print "<td valign=middle>";
print &ui_textbox("name", ( $sha ? $sha->{'values'}->[0] : "" ), 15);
print "</td>";

&display_params($sconf, "shared-network");

print "<tr><td valign=top colspan=4><table border=0 width=100%>\n";
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
print "<td valign=top>";
my @esh_hosts;
foreach $h (@host) {
	next if !&can('r', \%access, $h);
    push(@esh_hosts, [$h->{'index'}.",".$inshar{$h}, $h->{'values'}->[0], ( (!$in{'new'}) && $inshar{$h} eq $sha->{'index'} ? "selected" : "" ) ] );
	}
print &ui_select("hosts", undef, \@esh_hosts, 3, 1);
print "</td>\n";

print "<td valign=top align=right><b>$text{'esh_groups'}</b></td>\n";
print "<td valign=top>";
my @esh_groups_sel;
foreach $g (@group) {
	my $gm = 0;
	next if !&can('r', \%access, $g);
	foreach $h (@{$g->{'members'}}) {
		if ($h->{'name'} eq "host") { $gm++; }
		}
    push(@esh_groups_sel, [$g->{'index'}.",".$inshar{$g}, &group_name($gm, $g), ( (!$in{'new'}) && $inshar{$g} eq $sha->{'index'} ? "selected" : "" ) ] );
	}
print &ui_select("groups", undef, \@esh_groups_sel, 3, 1);
print "</td>\n";

print "<td valign=top align=right><b>$text{'esh_subn'}</b></td>\n";
print "<td valign=top>";
my @esh_subn_sel;
foreach $s (@subn) {
	next if !&can('r', \%access, $s);
    push(@esh_subn_sel, [$s->{'index'}.",".$inshar{$s}, $s->{'values'}->[0], ( (!$in{'new'}) && $inshar{$s} eq $sha->{'index'} ? "selected" : "" ) ] );
	}
print &ui_select("subnets", undef, \@esh_subn_sel, 3, 1);
print "</td>\n";

if (!$in{'new'}) {
	# inaccessible hosts in this shared network
	foreach $h (@host) {
		if (!&can('r', \%access, $h) && $inshar{$h} eq $sha->{'index'}) {
            print &ui_hidden("hosts","$h->{'index'},$sha->{'index'}");
			}
		}
	# inaccessible groups in this shared network
	foreach $g (@group) {
		if (!&can('r', \%access, $g) && $inshar{$g} eq $sha->{'index'}) {
            print &ui_hidden("groups","$g->{'index'},$sha->{'index'}");
			}
		}
	# inaccessible subnets in this shared network
	foreach $s (@subn) {
		if (!&can('r', \%access, $s) && $inshar{$s} eq $sha->{'index'}) {
            print &ui_hidden("subnets","$s->{'index'},$sha->{'index'}");
			}
		}
	}
print "</table></td></tr>\n";

print &ui_table_end();

if (!$in{'new'}) {
    print &ui_hidden("idx", $in{'idx'});
	print "<table width=100%><tr>\n";
	print "<td>";
    print &ui_submit($text{'save'}) if &can('rw', \%access, $sha);  
    print "</td>";
	print "<td align=center>";
    print &ui_submit( (&can('rw', \%access, $sha) ? $text{'butt_eco'} : $text{'butt_vco'} ), "options");
	print "</td>";
	print "<td align=right>";
    print &ui_submit($text{'delete'}, "delete") if &can('rw', \%access, $sha, 1);
	print "</td>";
	print "</tr></table>\n";
    if ( &can('rw', \%access, $sha) ) {
        print &ui_link("edit_host.cgi?new=1&sidx=$in{'idx'}&ret=shared",$text{'index_addhst'})."&nbsp;&nbsp;";
        print &ui_link("edit_group.cgi?new=1&sidx=$in{'idx'}&ret=shared",$text{'index_addhstg'})."&nbsp;&nbsp;";
        print &ui_link("edit_subnet.cgi?new=1&sidx=$in{'idx'}&ret=shared",$text{'index_addsub'})."&nbsp;&nbsp;";
        }
	}
else {
    print &ui_hidden("new",1);
    print &ui_submit($text{'create'});
	}

if ($config{'dhcpd_version'} >= 3 && !$in{'new'}) {
	# Display address pools
	print &ui_hr();
	print &ui_subheading($text{'esh_pools'});
	my $pn = 1;
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
    print &ui_link("edit_pool.cgi?uidx=$in{'idx'}&new=1",$text{'esub_pooladd'});
    print "<br>";
	}

print &ui_form_end();
&ui_print_footer("", $text{'esh_return'});

