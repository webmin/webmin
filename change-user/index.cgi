#!/usr/local/bin/perl
# index.cgi
# Display the user's current language, theme and password

use strict;
use warnings;
require './change-user-lib.pl';
our (%text, %access, $base_remote_user, $default_lang, %gconfig);
&ui_print_header(undef, $text{'index_title'}, "", undef, 0, 1);

my @users = &acl::list_users();
my ($user) = grep { $_->{'name'} eq $base_remote_user } @users;

my @can;
push(@can, 'lang') if ($access{'lang'});
push(@can, 'theme') if ($access{'theme'});
push(@can, 'pass') if ($access{'pass'} && &can_change_pass($user));
my $can = &text('index_d'.scalar(@can), map { $text{'index_d'.$_} } @can);
print &text('index_desc2', $can),"<p>\n";

print &ui_form_start("change.cgi", "post");
print &ui_table_start(undef, undef, 2);

if ($access{'lang'}) {
	# Show personal language
	my $glang = $gconfig{"lang"} || $default_lang;
	my @langs = &list_languages($user->{'lang'} || $glang);
	my ($linfo) = grep { $_->{'lang'} eq $glang } @langs;
	print &ui_table_row($text{'index_lang'},
		&ui_radio("lang_def", $user->{'lang'} ? 0 : 1,
			  [ [ 1, &text('index_langglobal2', $linfo->{'desc'},
				       $linfo->{'lang'})."<br>" ],
			    [ 0, $text{'index_langset'} ] ])." ".
		&ui_select("lang", $user->{'lang'},
			   [ map { [ $_->{'lang'},
				     $_->{'desc'}." (".uc($_->{'lang'}).")" ] }
			         &list_languages() ]), undef, [ "valign=top","valign=top" ] );
	}

if ($access{'theme'}) {
	# Show personal theme
	my $tname;
	if ($gconfig{'theme'}) {
		my ($gtheme, $goverlay) = split(/\s+/, $gconfig{'theme'});
		my %tinfo = &webmin::get_theme_info($gtheme);
		$tname = $tinfo{'desc'};
		}
	else {
		$tname = $text{'index_themedef'};
		}
	my @all = &webmin::list_visible_themes($user->{'theme'});
	my @themes = grep { !$_->{'overlay'} } @all;
	my @overlays = grep { $_->{'overlay'} } @all;

	# Main theme
	print &ui_table_row($text{'index_theme'},
		&ui_radio("theme_def", defined($user->{'theme'}) ? 0 : 1,
			  [ [ 1, &text('index_themeglobal', $tname)."<br>" ],
			    [ 0, $text{'index_themeset'} ] ])." ".
		&ui_select("theme", $user->{'theme'},
			[ [ '', $text{'index_themedef'} ],
			  map { [ $_->{'dir'}, $_->{'desc'} ] }
			      @themes ]), undef, [ "valign=top","valign=top" ]);

	# Overlay, if any
	if (@overlays) {
		print &ui_table_row($text{'index_overlay'},
			&ui_select("overlay", $user->{'overlay'},
				[ [ '', $text{'index_overlaydef'} ],
				  map { [ $_->{'dir'}, $_->{'desc'} ] }
				      @overlays ]), undef, [ "valign=middle","valign=middle" ]);
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
		&ui_password("pass2", undef, 20), undef, [ "valign=top","valign=middle" ]);
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'index_ok'} ] ]);

&ui_print_footer("/", $text{'index'});

