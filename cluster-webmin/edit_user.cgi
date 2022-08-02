#!/usr/local/bin/perl
# edit_user.cgi
# Display details of an existing user for changing

require './cluster-webmin-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'user_title2'}, "");

@hosts = &list_webmin_hosts();
@mods = &all_modules(\@hosts);
@themes = &all_themes(\@hosts);
@wgroups = &all_groups(\@hosts);
@servers = &list_servers();
if ($in{'host'} ne '') {
	($host) = grep { $_->{'id'} == $in{'host'} } @hosts;
	($user) = grep { $_->{'name'} eq $in{'user'} } @{$host->{'users'}};
	}
else {
	foreach $h (@hosts) {
		local ($u) = grep { $_->{'name'} eq $in{'user'} } @{$h->{'users'}};
		if ($u) {
			$host = $h;
			$user = $u;
			last;
			}
		}
	}
($serv) = grep { $_->{'id'} == $host->{'id'} } @servers;
foreach $h (@hosts) {
	local ($u) = grep { $_->{'name'} eq $in{'user'} } @{$h->{'users'}};
	if ($u) {
		push(@got, grep { $_->{'id'} == $h->{'id'} } @servers);
		}
	}

print "<form action=save_user.cgi method=post>\n";
print "<input type=hidden name=old value=\"$in{'user'}\">\n";
print "<input type=hidden name=host value=\"$host->{'id'}\">\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>",&text('user_header2', &server_name($serv)),
      "</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'user_name'}</b></td>\n";
printf "<td><input name=name size=15 value='%s'></td> </tr>\n",
	$user->{'name'};

foreach $g (@{$host->{'groups'}}) {
	if (&indexof($user->{'name'}, @{$g->{'members'}}) >= 0) {
		$group = $g;
		last;
		}
	}
print "<tr> <td><b>$text{'user_group'}</b></td> <td>\n";
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

print "<tr> <td><b>$text{'user_pass'}</b></td> <td>\n";
print "<select name=pass_def>\n";
print "<option value=1 checked>$text{'user_leave'}</option>\n";
print "<option value=0>$text{'user_set'} ..</option>\n";
print "<option value=3>$text{'user_unix'}</option>\n";
print "<option value=4>$text{'user_lock'}</option>\n";
print "<option value=5>$text{'user_extauth'}</option>\n";
print "</select><input type=password name=pass size=25></td> </tr>\n";

@langs = &list_languages();
my $ulang = safe_language($user->{'lang'});
%langdesc = map { $_->{'lang'}, $_->{'desc'} } @langs;
print "<tr> <td><b>$text{'user_lang'}</b></td> <td>\n";
printf "<input type=radio name=lang_def value=1 checked> %s (%s)\n",
	$text{'user_leave'}, $ulang ? $langdesc{$ulang}
					     : $text{'user_default'};
printf "<input type=radio name=lang_def value=0> %s\n",
	$text{'user_set'};
print "<select name=lang>\n";
print "<option value='' selected>$text{'user_default'}</option>\n";
foreach $l (@langs) {
	printf "<option value=%s>%s</option>\n",
		$l->{'lang'},
		$l->{'desc'};
	}
print "</select></td> </tr>\n";

%themedesc = map { $_->{'dir'}, $_->{'desc'} } @themes;
print "<tr> <td><b>$text{'user_theme'}</b></td> <td>\n";
printf "<input type=radio name=theme_def value=1 checked> %s (%s)\n",
	$text{'user_leave'},
	$user->{'theme'} ? $themedesc{$user->{'theme'}} :
	!defined($user->{'theme'}) ? $text{'user_default'} : $text{'user_themedef'};
printf "<input type=radio name=theme_def value=0> %s\n",
	$text{'user_set'};
print "<select name=theme>\n";
print "<option value=webmin selected>$text{'user_default'}</option>\n";
foreach $t ( { 'desc' => $text{'user_themedef'} }, @themes) {
	printf "<option value='%s'>%s</option>\n", $t->{'dir'}, $t->{'desc'};
	}
print "</select></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'user_notabs'}</b></td>\n";
print "<td>",ui_radio("notabs", int($user->{'notabs'}),
                          [ [ 1, $text{'yes'} ],
                            [ 2, $text{'no'} ],
                            [ 0, $text{'default'} ] ]),"</td> </tr>\n";

print "<tr> <td valign=top><b>$text{'user_ips'}</b></td>\n";
print "<td>\n";
print "<input name=ipmode type=radio value=-1 checked> $text{'user_leave'}\n";
if ($user->{'allow'}) {
	print "($text{'user_allow2'} $user->{'allow'})\n";
	}
elsif ($user->{'deny'}) {
	print "($text{'user_deny2'} $user->{'deny'})\n";
	}
else {
	print "($text{'user_allowall'})\n";
	}
print "<table cellpadding=0 cellspacing=0><tr><td valign=top>\n";
print "<input name=ipmode type=radio value=0> $text{'user_allips'}<br>\n";
print "<input name=ipmode type=radio value=1> $text{'user_allow'}<br>\n";
print "<input name=ipmode type=radio value=2> $text{'user_deny'}</td>\n";
print "<td><textarea name=ips rows=4 cols=30></textarea></td>\n";
print "</td> </tr></table> </tr>\n";

$mp = int((scalar(@mods)+2)/3);
@umods = $group ? @{$user->{'ownmods'}} : @{$user->{'modules'}};
map { $umods{$_}++ } @umods;
print "<tr> <td valign=top><b>$text{'user_mods'}</b><br>",
      "$text{'user_groupmods'}</td> <td nowrap>\n";
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
	local ($u) = grep { $_->{'name'} eq $in{'user'} } @{$h->{'users'}};
	next if (!$u);
	local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
	local $d = &server_name($s);
	$sel .= "<option value='$h->{'id'},'>".&text('user_aclhg', $d)."</option>\n"
		if (!$ingroup{$in{'user'}});
	foreach $m (@{$h->{'modules'}}) {
		local @um = $ingroup{$in{'user'}} ? @{$u->{'ownmods'}}
						  : @{$u->{'modules'}};
		next if (&indexof($m->{'dir'}, @um) < 0);
		$sel .= "<option value='$h->{'id'},$m->{'dir'}'>".
			&text('user_aclh', $m->{'desc'}, $d)."</option>\n";
		}
	}
if ($sel) {
	print "<form action=edit_acl.cgi><td align=center>\n";
	print "<input type=hidden name=user value='$in{'user'}'>\n";
	print "<input type=submit value='$text{'user_acl'}'>\n";
	print "<select name=modhost>\n";
	print $sel;
	print "</select></td></form>\n";
	}

print "<form action=delete_user.cgi>\n";
print "<input type=hidden name=user value=\"$in{'user'}\">\n";
print "<td align=right><input type=submit value='$text{'delete'}'></td></form>\n";
print "</tr></table>\n";

# Show hosts with the user
print &ui_hr();
print &ui_subheading($text{'user_hosts'});
@icons = map { "/servers/images/$_->{'type'}.svg" } @got;
@links = map { "edit_host.cgi?id=$_->{'id'}" } @got;
@titles = map { &server_name($_) } @got;
&icons_table(\@links, \@titles, \@icons);

&ui_print_footer("", $text{'index_return'});

