#!/usr/local/bin/perl
# edit_user.cgi
# Edit a new or existing webmin user

require './acl-lib.pl';
&foreign_require("webmin", "webmin-lib.pl");

&ReadParse();
if ($in{'user'}) {
	# Editing an existing user
	&can_edit_user($in{'user'}) || &error($text{'edit_euser'});
	&ui_print_header(undef, $text{'edit_title'}, "");
	foreach $u (&list_users()) {
		if ($u->{'name'} eq $in{'user'}) {
			%user = %$u;
			}
		if ($u->{'name'} eq $base_remote_user) {
			$me = $u;
			}
		}
	}
else {
	# Creating a new user
	$access{'create'} || &error($text{'edit_ecreate'});
	&ui_print_header(undef, $text{'edit_title2'}, "");
	foreach $u (&list_users()) {
		if ($u->{'name'} eq $in{'clone'}) {
			$user{'modules'} = $u->{'modules'};
			$user{'lang'} = $u->{'lang'};
			}
		if ($u->{'name'} eq $base_remote_user) {
			$me = $u;
			}
		}
	$user{'skill'} = $user{'risk'} = 'high' if ($in{'risk'});
	}

# Give up if readonly
if ($user{'readonly'} && !$in{'readwrite'}) {
	%minfo = &get_module_info($user{'readonly'});
	print &text('edit_readonly', $minfo{'desc'},
		    "edit_user.cgi?user=$in{'user'}&readwrite=1"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

print "<form action=save_user.cgi method=post>\n";
if ($in{'user'}) {
	print "<input type=hidden name=old value=\"$user{'name'}\">\n";
	print "<input type=hidden name=oldpass value=\"$user{'pass'}\">\n";
	}
if ($in{'clone'}) {
	print "<input type=hidden name=clone value=\"$in{'clone'}\">\n";
	}
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_rights'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'edit_user'}</b></td>\n";
if ($access{'rename'} || !$in{'user'}) {
	print "<td><input name=name size=25 ",
	      "value=\"$user{'name'}\"></td>\n";
	}
else {
	print "<td>$user{'name'}</td>\n";
	}

# Find and show parent group
@glist = &list_groups();
@mcan = $access{'gassign'} eq '*' ?
		( ( map { $_->{'name'} } @glist ), '_none' ) :
		split(/\s+/, $access{'gassign'});
map { $gcan{$_}++ } @mcan;
if (@glist && %gcan && !$in{'risk'} && !$user{'risk'}) {
	print "<td><b>$text{'edit_group'}</b></td>\n";
	print "<td><select name=group>\n";
	foreach $g (@glist) {
		local $mem = &indexof($user{'name'}, @{$g->{'members'}}) >= 0;
		next if (!$gcan{$g->{'name'}} && !$mem);
		printf "<option %s>%s\n",
			$mem ?  'selected' : '', $g->{'name'};
		$group = $g if ($mem);
		}
	printf "<option value='' %s>&lt;%s&gt;\n",
		$group ? '' : 'selected', $text{'edit_none'}
			if ($gcan{'_none'});
	print "</select></td>\n";
	}
print "</tr>\n";

# Show password type menu and current password
$passmode = !$in{'user'} ? 0 :
	    $user{'pass'} eq 'x' ? 3 :
	    $user{'sync'} ? 2 :
	    $user{'pass'} eq 'e' ? 5 :
	    $user{'pass'} eq '*LK*' ? 4 : 1;
print "<tr> <td><b>$text{'edit_pass'}</b></td> <td colspan=3>\n";
print "<select name=pass_def>\n";
printf "<option value=0 %s> $text{'edit_set'} ..\n",
	$passmode == 0 ? "selected" : "";
if ($in{'user'}) {
	printf "<option value=1 %s> %s\n",
		$passmode == 1 ? "selected" : "", $text{'edit_dont'};
	}
printf "<option value=3 %s> $text{'edit_unix'}\n",
	$passmode == 3 ? "selected" : "";
if ($user{'sync'}) {
	printf "<option value=2 %s> $text{'edit_same'}\n",
		$passmode == 2 ? "selected" : "";
	}
&get_miniserv_config(\%miniserv);
if ($miniserv{'extauth'}) {
	printf "<option value=5 %s> $text{'edit_extauth'}\n",
		$passmode == 5 ? "selected" : "";
	}
printf "<option value=4 %s> $text{'edit_lock'}\n",
	$passmode == 4 ? "selected" : "";
print "</select><input type=password name=pass size=25>\n";
if ($passmode == 1) {
	# Show temporary lock option
	print &ui_checkbox("lock", 1, $text{'edit_templock'},
			   $user{'pass'} =~ /^\!/ ? 1 : 0);
	}
print "</td> </tr>\n";

if ($access{'chcert'}) {
	# SSL certificate name
	print "<tr> <td><b>$text{'edit_cert'}</b></td> <td colspan=3>\n";
	print &ui_opt_textbox("cert", $user{'cert'}, 50, $text{'edit_none'}),
	      "</td></tr>\n";
	}

if ($access{'lang'}) {
	# Current language
	print "<tr> <td><b>$text{'edit_lang'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=lang_def value=1 %s> %s\n",
		$user{'lang'} ? '' : 'checked', $text{'default'};
	printf "<input type=radio name=lang_def value=0 %s>\n",
		$user{'lang'} ? 'checked' : '';
	print "<select name=lang>\n";
	foreach $l (&list_languages()) {
		printf "<option value=%s %s>%s (%s)\n",
			$l->{'lang'},
			$user{'lang'} eq $l->{'lang'} ? 'selected' : '',
			$l->{'desc'}, uc($l->{'lang'});
		}
	print "</select></td> </tr>\n";
	}

if ($access{'cats'}) {
	# Show categorized modules?
	print "<tr> <td><b>$text{'edit_notabs'}</b></td> <td colspan=2>\n";
	printf "<input type=radio name=notabs value=1 %s> %s\n",
		$user{'notabs'} == 1 ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=notabs value=2 %s> %s\n",
		$user{'notabs'} == 2 ? 'checked' : '', $text{'no'};
	printf "<input type=radio name=notabs value=0 %s> %s</td> </tr>\n",
		$user{'notabs'} == 0 ? 'checked' : '', $text{'default'};
	}

if ($access{'logouttime'}) {
	# Show logout time
	print "<tr> <td><b>$text{'edit_logout'}</b></td> <td colspan=2>\n";
	print &ui_opt_textbox("logouttime", $user{'logouttime'}, 5,
		      $text{'default'})," $text{'edit_mins'}</td> </tr>\n";
	}

if ($access{'theme'}) {
	# Current theme
	print "<tr> <td><b>$text{'edit_theme'}</b></td> <td colspan=2>\n";
	printf "<input type=radio name=theme_def value=1 %s> %s\n",
		defined($user{'theme'}) ? "" : "checked", $text{'edit_themeglobal'};
	printf "<input type=radio name=theme_def value=0 %s>\n",
		defined($user{'theme'}) ? "checked" : "";
	print "<select name=theme>\n";
	foreach $t ( { 'desc' => $text{'edit_themedef'} },
		     &foreign_call("webmin", "list_themes")) {
		printf "<option value='%s' %s>%s\n",
		  $t->{'dir'}, $user{'theme'} eq $t->{'dir'} ? 'selected' : '',
		  $t->{'desc'};
		}
	print "</select></td> </tr>\n";
	}

if ($access{'ips'}) {
	# Allowed IP addresses
	print "<tr> <td>",&hlink("<b>$text{'edit_ips'}</b>", "ips"),"</td>\n";
	print "<td colspan=3><table><tr>\n";
	printf "<td nowrap><input name=ipmode type=radio value=0 %s> %s<br>\n",
		$user{'allow'} || $user{'deny'} ? '' : 'checked',
		$text{'edit_all'};
	printf "<input name=ipmode type=radio value=1 %s> %s<br>\n",
		$user{'allow'} ? 'checked' : '', $text{'edit_allow'};
	printf "<input name=ipmode type=radio value=2 %s> %s</td> <td>\n",
		$user{'deny'} ? 'checked' : '', $text{'edit_deny'};
	print "<textarea name=ips rows=4 cols=30>",
	      join("\n", split(/\s+/, $user{'allow'} ? $user{'allow'}
						     : $user{'deny'})),
	      "</textarea></td>\n";
	print "</td></tr></table> </tr>\n";
	}

if (&supports_rbac() && $access{'mode'} == 0) {
	# Deny access to modules not managed by RBAC?
	print "<tr> <td><b>$text{'edit_rbacdeny'}</b></td> <td colspan=3>\n";
	print &ui_radio("rbacdeny", $user{'rbacdeny'} ? 1 : 0,
			[ [ 0, $text{'edit_rbacdeny0'} ],
			  [ 1, $text{'edit_rbacdeny1'} ] ]); 
	print "</td> </tr>\n";
	}

if ($access{'times'}) {
	# Show allowed days of the week
	%days = map { $_, 1 } split(/,/, $user{'days'});
	print "<tr> <td valign=top><b>$text{'edit_days'}</b></td>\n";
	print "<td colspan=3>\n";
	print &ui_radio("days_def", $user{'days'} eq '' ? 1 : 0,
			[ [ 1, $text{'edit_alldays'} ],
			  [ 0, $text{'edit_seldays'} ] ]),"<br>\n";
	for(my $i=0; $i<7; $i++) {
		print &ui_checkbox("days", $i, $text{'day_'.$i}, $days{$i});
		}
	print "</td> </tr>\n";

	# Show allow hour/minute range
	($hf, $mf) = split(/\./, $user{'hoursfrom'});
	($ht, $mt) = split(/\./, $user{'hoursto'});
	print "<tr> <td valign=top><b>$text{'edit_hours'}</b></td>\n";
	print "<td colspan=3>\n";
	print &ui_radio("hours_def", $user{'hoursfrom'} eq '' ? 1 : 0,
		[ [ 1, $text{'edit_allhours'} ],
		  [ 0, &text('edit_selhours',
			&ui_textbox("hours_hfrom", $hf, 2),
			&ui_textbox("hours_mfrom", $mf, 2),
			&ui_textbox("hours_hto", $ht, 2),
			&ui_textbox("hours_mto", $mt, 2)) ] ]);
	print "</td> </tr>\n";
	}

if ($user{'risk'} || $in{'risk'}) {
	# Creating or editing a risk-level user
	print "<tr> <td><b>$text{'edit_risk'}</b></td> <td colspan=3>\n";
	foreach $s ('high', 'medium', 'low') {
		printf "<input type=radio name=risk value='%s' %s> %s\n",
		    $s, $user{'risk'} eq $s ? 'checked' : '',
		    $text{"edit_risk_$s"};
		}
	print "</td> </tr>\n";

	print "<tr> <td><b>$text{'edit_skill'}</b></td> <td colspan=3>\n";
	foreach $s ('high', 'medium', 'low') {
		printf "<input type=radio name=skill value='%s' %s> %s\n",
		    $s, $user{'skill'} eq $s ? 'checked' : '',
		    $text{"skill_$s"};
		}
	print "</td> </tr>\n";
	}
else {
	# Creating or editing a normal user
	@mcan = $access{'mode'} == 1 ? @{$me->{'modules'}} :
		$access{'mode'} == 2 ? split(/\s+/, $access{'mods'}) :
				       &list_modules();
	map { $mcan{$_}++ } @mcan;
	map { $has{$_}++ } @{$user{'modules'}};
	map { $has{$_} = 0 } $group ? @{$group->{'modules'}} : ();

	# Show all modules, under categories
	@mlist = grep { $access{'others'} || $has{$_->{'dir'}} || $mcan{$_->{'dir'}} } &list_module_infos();
	print "<tr> <td valign=top><b>$text{'edit_modules'}</b><br>",
	      "$text{'edit_groupmods'}</td>\n";
	print "<td colspan=3>\n";
	print &select_all_link("mod", 0, $text{'edit_selall'}),"&nbsp;\n";
	print &select_invert_link("mod", 0, $text{'edit_invert'}),"<br>\n";
	@cats = &unique(map { $_->{'category'} } @mlist);
	&read_file("$config_directory/webmin.catnames", \%catnames);
	print "<table width=100% cellpadding=0 cellspacing=0>\n";
	foreach $c (sort { $b cmp $a } @cats) {
		@cmlist = grep { $_->{'category'} eq $c } @mlist;
		print "<tr> <td colspan=2 $tb><b>",
			$catnames{$c} || $text{'category_'.$c},
			"</b></td> </tr>\n";
		$sw = 0;
		foreach $m (@cmlist) {
			local $md = $m->{'dir'};
			if (!$sw) { print "<tr>\n"; }
			print "<td width=50%>";
			if ($mcan{$md}) {
				printf"<input type=checkbox name=mod value=$md %s>\n",
				      $has{$md} ? "checked" : "";
				if ($access{'acl'} && $in{'user'}) {
					# Show link for editing ACL
					printf "<a href='edit_acl.cgi?mod=%s&%s=%s'>".
					       "%s</a>\n",
						&urlize($m->{'dir'}),
						"user", &urlize($in{'user'}),
						$m->{'desc'};
					}
				else {
					print "$m->{'desc'}\n";
					}
				}
			else {
				printf "<img src=images/%s.gif> %s\n",
				    $has{$md} ? 'tick' : 'empty', $m->{'desc'};
				}
			print "</td>";
			if ($sw) { print "<tr>\n"; }
			$sw = !$sw;
			}
		}
	if ($access{'acl'}) {
		print "<tr> <td colspan=2 $tb><b>",
		      $text{'edit_special'},"</b></td> </tr>\n";
		print "<tr>\n";
		print "<td><a href='edit_acl.cgi?mod=&user=",&urlize($in{'user'}),
		      "'>",$text{'index_global'},"</a></td>\n";
		print "</tr>\n";
		}
	print "</table>\n";
	print &select_all_link("mod", 0, $text{'edit_selall'}),"&nbsp;\n";
	print &select_invert_link("mod", 0, $text{'edit_invert'}),"\n";
	print "</td> </tr>\n";
	}
print "</table></td> </tr></table>\n";

print "<table width=100%> <tr>\n";
print "<td align=left width=16%><input type=submit value=\"$text{'save'}\"></td></form>\n";
if ($in{'user'}) {
	if (!$group) {
		print "<form action=hide_form.cgi>\n";
		print "<input type=hidden name=user value=\"$in{'user'}\">\n";
		print "<td align=center width=16%>",
		      "<input type=submit value=\"$text{'edit_hide'}\"></td></form>\n";
		}
	else { print "<td width=16%></td>\n"; }

	if ($access{'create'} && !$group) {
		print "<form action=edit_user.cgi>\n";
		print "<input type=hidden name=clone value=\"$in{'user'}\">\n";
		print "<td align=center width=16%>",
		      "<input type=submit value=\"$text{'edit_clone'}\">",
		      "</td></form>\n";
		}
	else { print "<td width=16%></td>\n"; }

	&read_acl(\%acl);
	if (&foreign_check("webminlog") &&
	    $acl{$base_remote_user,'webminlog'}) {
		print "<form action=/webminlog/search.cgi>\n";
		print "<input type=hidden name=uall value=0>\n";
		print "<input type=hidden name=user value='$in{'user'}'>\n";
		print "<input type=hidden name=mall value=1>\n";
		print "<input type=hidden name=tall value=0>\n";
		print "<td align=center width=16%>",
		      "<input type=submit value=\"$text{'edit_log'}\">",
		      "</td></form>\n";
		}
	else { print "<td width=16%></td>\n"; }

	if ($access{'switch'} && $main::session_id) {
		print "<form action=switch.cgi>\n";
		print "<input type=hidden name=user value=\"$in{'user'}\">\n";
		print "<td align=center width=16%>",
		      "<input type=submit value=\"$text{'edit_switch'}\">",
		      "</td></form>\n";
		}
	else { print "<td width=16%></td>\n"; }

	if ($access{'delete'}) {
		print "<form action=delete_user.cgi>\n";
		print "<input type=hidden name=user value=\"$in{'user'}\">\n";
		print "<td align=right width=16%>",
		      "<input type=submit value=\"$text{'delete'}\"></td></form>\n";
		}
	else { print "<td width=16%></td>\n"; }
	}
print "</tr> </table>\n";

&ui_print_footer("", $text{'index_return'});

