#!/usr/local/bin/perl
# index.cgi
# Display the user's current language, theme and password

require './change-user-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", undef, 0, 1);

@users = &acl::list_users();
($user) = grep { $_->{'name'} eq $base_remote_user } @users;

push(@can, 'lang') if ($access{'lang'});
push(@can, 'theme') if ($access{'theme'});
push(@can, 'pass') if ($access{'pass'} && &can_change_pass($user));
$can = &text('index_d'.scalar(@can), map { $text{'index_d'.$_} } @can);
print &text('index_desc2', $can),"<p>\n";

print "<form action=change.cgi method=post>\n";
print "<table>\n";

if ($access{'lang'}) {
	# Show personal language
	@langs = &list_languages();
	$glang = $gconfig{"lang"} || $default_lang;
	($linfo) = grep { $_->{'lang'} eq $glang } @langs;
	print "<tr> <td valign=top><b>$text{'index_lang'}</b></td> <td>\n";
	printf "<input type=radio name=lang_def value=1 %s> %s<br>\n",
		$user->{'lang'} ? "" : "checked",
		&text('index_langglobal', $linfo->{'desc'});
	printf "<input type=radio name=lang_def value=0 %s> %s\n",
		$user->{'lang'} ? "checked" : "", $text{'index_langset'};
	print "<select name=lang>\n";
	foreach $l (&list_languages()) {
		printf "<option value=%s %s>%s (%s)\n",
			$l->{'lang'},
			$user->{'lang'} eq $l->{'lang'} ? 'selected' : '',
			$l->{'desc'}, uc($l->{'lang'});
		}
	print "</select></td> </tr>\n";
	}

if ($access{'theme'}) {
	# Show personal theme
	if ($gconfig{'theme'}) {
		%tinfo = &webmin::get_theme_info($gconfig{'theme'});
		$tname = $tinfo{'desc'};
		}
	else {
		$tname = $text{'index_themedef'};
		}
	print "<tr> <td valign=top><b>$text{'index_theme'}</b></td> <td>\n";
	printf "<input type=radio name=theme_def value=1 %s> %s<br>\n",
		defined($user->{'theme'}) ? "" : "checked",
		&text('index_themeglobal', $tname);
	printf "<input type=radio name=theme_def value=0 %s> %s\n",
		defined($user->{'theme'}) ? "checked" : "", $text{'index_themeset'};
	print "<select name=theme>\n";
	foreach $t ( { 'desc' => $text{'index_themedef'} }, &webmin::list_themes() ) {
		printf "<option value='%s' %s>%s\n",
		  $t->{'dir'}, $user->{'theme'} eq $t->{'dir'} ? 'selected' : '',
		  $t->{'desc'};
		}
	print "</select></td> </tr>\n";
	}

if ($access{'pass'} && &can_change_pass($user)) {
	# Show password
	print "<tr> <td valign=top><b>$text{'index_pass'}</b></td> <td>\n";
	printf "<input type=radio name=pass_def value=1 %s> %s<br>\n",
		"checked", $text{'index_passleave'};
	printf "<input type=radio name=pass_def value=0 %s> %s\n",
		"", $text{'index_passset'};
	print "<input type=password name=pass size=20></td> </tr>\n";
	}

print "</table>\n";
print "<input type=submit value='$text{'index_ok'}'></form>\n";

&ui_print_footer("/", $text{'index'});

