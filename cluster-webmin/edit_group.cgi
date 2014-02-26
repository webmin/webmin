#!/usr/local/bin/perl
# edit_group.cgi
# Display an existing Webmin group for editing

require './cluster-webmin-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'group_title2'}, "");

@hosts = &list_webmin_hosts();
@mods = &all_modules(\@hosts);
@wgroups = &all_groups(\@hosts);
@servers = &list_servers();
if ($in{'host'} ne '') {
	($host) = grep { $_->{'id'} == $in{'host'} } @hosts;
	($edgrp) = grep { $_->{'name'} eq $in{'group'} } @{$host->{'groups'}};
	}
else {
	foreach $h (@hosts) {
		local ($g) =grep { $_->{'name'} eq $in{'group'} } @{$h->{'groups'}};
		if ($g) {
			$host = $h;
			$edgrp = $g;
			last;
			}
		}
	}
($serv) = grep { $_->{'id'} == $host->{'id'} } @servers;
foreach $h (@hosts) {
	local ($g) = grep { $_->{'name'} eq $in{'group'} } @{$h->{'groups'}};
	if ($g) {
		push(@got, grep { $_->{'id'} == $h->{'id'} } @servers);
		}
	}

print "<form action=save_group.cgi method=post>\n";
print "<input type=hidden name=old value=\"$in{'group'}\">\n";
print "<input type=hidden name=host value=\"$host->{'id'}\">\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>",&text('group_header2', &server_name($serv)),
      "</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'group_name'}</b></td>\n";
printf "<td><input name=name size=15 value='%s'></td> </tr>\n",
	$edgrp->{'name'};

@gm = @{$edgrp->{'members'}};
print "<tr> <td><b>$text{'group_mems'}</b></td>\n";
print "<td>",@gm ? join(" ", @gm) : $text{'group_nomems'},"</td> </tr>\n";

foreach $g (@{$host->{'groups'}}) {
	if (&indexof($edgrp->{'name'}, @{$g->{'members'}}) >= 0) {
		$group = $g;
		last;
		}
	}
print "<tr> <td><b>$text{'group_group'}</b></td> <td>\n";
printf "<input type=radio name=group_def value=1 checked> %s (%s)\n",
	$text{'user_leave'}, $group ? $group->{'name'} : $text{'user_nogroup2'};
printf "<input type=radio name=group_def value=0> %s\n",
	$text{'user_set'};
print "<select name=group>\n";
print "<option selected value=''>$text{'user_nogroup'}</option>\n";
foreach $g (@wgroups) {
	print "<option>$g->{'name'}</option>\n";
	}
print "</select></td> </tr>\n";

$mp = int((scalar(@mods)+2)/3);
@umods = $group ? @{$edgrp->{'ownmods'}} : @{$edgrp->{'modules'}};
map { $umods{$_}++ } @umods;
print "<tr> <td valign=top><b>$text{'group_mods'}</b><br>",
      "$text{'group_groupmods'}</td> <td nowrap>\n";
print "<input type=radio name=mods_def value=1 checked> ",
	&text('user_mleave', scalar(@umods)),"<br>\n";
print "<input type=radio name=mods_def value=2> $text{'user_modsel'}\n";
print "<input type=radio name=mods_def value=3> $text{'user_modadd'}\n";
print "<input type=radio name=mods_def value=0> $text{'user_moddel'}\n";
print "<br>\n";
print "<select name=mods1 size=$mp multiple>\n";
for($i=0; $i<$mp; $i++) {
	printf "<option value=%s %s>%s</option>\n",
		$mods[$i]->{'dir'}, $umods{$mods[$i]->{'dir'}} ? "selected" : "",
		$mods[$i]->{'desc'};
	}
print "</select>\n";
print "<select name=mods2 size=$mp multiple>\n";
for($i=$mp; $i<$mp*2; $i++) {
	printf "<option value=%s %s>%s</option>\n",
		$mods[$i]->{'dir'}, $umods{$mods[$i]->{'dir'}} ? "selected" : "",
		$mods[$i]->{'desc'};
	}
print "</select>\n";
print "<select name=mods3 size=$mp multiple>\n";
for($i=$mp*2; $i<@mods; $i++) {
	printf "<option value=%s %s>%s</option>\n",
		$mods[$i]->{'dir'}, $umods{$mods[$i]->{'dir'}} ? "selected" : "",
		$mods[$i]->{'desc'};
	}
print "</select>\n";

print "<br>\n";
print "<a href='' onClick='for(i=0; i<document.forms[0].mods1.options.length; i++) { document.forms[0].mods1.options[i].selected = true; } for(i=0; i<document.forms[0].mods2.options.length; i++) { document.forms[0].mods2.options[i].selected = true; } for(i=0; i<document.forms[0].mods3.options.length; i++) { document.forms[0].mods3.options[i].selected = true; } return false'>$text{'user_sall'}</a>&nbsp;\n";
print "<a href='' onClick='for(i=0; i<document.forms[0].mods1.options.length; i++) { document.forms[0].mods1.options[i].selected = false; } for(i=0; i<document.forms[0].mods2.options.length; i++) { document.forms[0].mods2.options[i].selected = false; } for(i=0; i<document.forms[0].mods3.options.length; i++) { document.forms[0].mods3.options[i].selected = false; } return false'>$text{'user_snone'}</a>&nbsp;\n";
print "<a href='' onClick='for(i=0; i<document.forms[0].mods1.options.length; i++) { document.forms[0].mods1.options[i].selected = !document.forms[0].mods1.options[i].selected; } for(i=0; i<document.forms[0].mods2.options.length; i++) { document.forms[0].mods2.options[i].selected = !document.forms[0].mods2.options[i].selected; } for(i=0; i<document.forms[0].mods3.options.length; i++) { document.forms[0].mods3.options[i].selected = !document.forms[0].mods3.options[i].selected; } return false'>$text{'user_sinvert'}</a><br>\n";

print "</td> </tr>\n";

print "</table></td></tr></table>\n";
print "<table width=100%><tr>\n";
print "<td><input type=submit value='$text{'save'}'></td></form>\n";

%mdesc = map { $_->{'dir'}, $_->{'desc'} } @mods;
foreach $h (@hosts) {
	local %ingroup;
	foreach $g (@{$h->{'groups'}}) {
		map { $ingroup{$_}++ } @{$g->{'members'}};
		}
	local ($g) = grep { $_->{'name'} eq $in{'group'} } @{$h->{'groups'}};
	next if (!$g);
	local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
	local $d = &server_name($s);
	$sel .= "<option value='$h->{'id'},'>".&text('user_aclhg', $d)."</option>\n"
		if (!$ingroup{$in{'group'}});
	foreach $m (@{$h->{'modules'}}) {
		local @gm = $ingroup{$in{'group'}} ? @{$g->{'ownmods'}}
						   : @{$g->{'modules'}};
		next if (&indexof($m->{'dir'}, @gm) < 0);
		$sel .= "<option value='$h->{'id'},$m->{'dir'}'>".
			&text('user_aclh', $m->{'desc'}, $d)."</option>\n";
		}
	}
if ($sel) {
	print "<form action=edit_acl.cgi><td align=center>\n";
	print "<input type=hidden name=group value='$in{'group'}'>\n";
	print "<input type=submit value='$text{'user_acl'}'>\n";
	print "<select name=modhost>\n";
	print $sel;
	print "</select></td></form>\n";
	}

print "<form action=delete_group.cgi>\n";
print "<input type=hidden name=group value=\"$in{'group'}\">\n";
print "<td align=right><input type=submit value='$text{'delete'}'></td></form>\n";
print "</tr></table>\n";

# Show hosts with the group
print &ui_hr();
print &ui_subheading($text{'group_hosts'});
@icons = map { "/servers/images/$_->{'type'}.gif" } @got;
@links = map { "edit_host.cgi?id=$_->{'id'}" } @got;
@titles = map { &server_name($_) } @got;
&icons_table(\@links, \@titles, \@icons);

&ui_print_footer("", $text{'index_return'});

