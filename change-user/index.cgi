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

print &ui_form_start("change.cgi", "post");
print &ui_table_start(undef, undef, 2);

if ($access{'lang'}) {
	# Show personal language
	@langs = &list_languages();
	$glang = $gconfig{"lang"} || $default_lang;
	($linfo) = grep { $_->{'lang'} eq $glang } @langs;
	print &ui_table_row($text{'index_lang'},
		&ui_radio("lang_def", $user->{'lang'} ? 0 : 1,
			  [ [ 1, &text('index_langglobal',
				       $linfo->{'desc'})."<br>" ],
			    [ 0, $text{'index_langset'} ] ])." ".
		&ui_select("lang", $user->{'lang'},
			   [ map { [ $_->{'lang'},
				     $_->{'desc'}." (".uc($_->{'lang'}).")" ] }
			         &list_languages() ]));
	}

if ($access{'theme'}) {
	# Show personal theme
	if ($gconfig{'theme'}) {
		($gtheme, $goverlay) = split(/\s+/, $gconfig{'theme'});
		%tinfo = &webmin::get_theme_info($gtheme);
		$tname = $tinfo{'desc'};
		}
	else {
		$tname = $text{'index_themedef'};
		}
	@all = &webmin::list_themes();
	@themes = grep { !$_->{'overlay'} } @all;
	@overlays = grep { $_->{'overlay'} } @all;

	# Main theme
	print &ui_table_row($text{'index_theme'},
		&ui_radio("theme_def", defined($user->{'theme'}) ? 0 : 1,
			  [ [ 1, &text('index_themeglobal', $tname)."<br>" ],
			    [ 0, $text{'index_themeset'} ] ])." ".
		&ui_select("theme", $user->{'theme'},
			[ [ '', $text{'index_themedef'} ],
			  map { [ $_->{'dir'}, $_->{'desc'} ] }
			      @themes ]));

	# Overlay, if any
	if (@overlays) {
		print &ui_table_row($text{'index_overlay'},
			&ui_select("overlay", $user->{'overlay'},
				[ [ '', $text{'index_overlaydef'} ],
				  map { [ $_->{'dir'}, $_->{'desc'} ] }
				      @overlays ]));
		}
	}

if ($access{'pass'} && &can_change_pass($user)) {
	# Show password
	print &ui_table_row($text{'index_pass'},
		&ui_radio("pass_def", 1,
			  [ [ 1, $text{'index_passleave'}."<br>" ],
			    [ 0, $text{'index_passset'} ] ])." ".
		&ui_password("pass", undef, 20)." ".
		$text{'index_passagain'}." ".
		&ui_password("pass2", undef, 20));
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'index_ok'} ] ]);

&ui_print_footer("/", $text{'index'});

