#!/usr/local/bin/perl
# index.cgi
# Display the user's current language, theme and password

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './change-user-lib.pl';
our (%text, %access, $base_remote_user, $default_lang, %gconfig);
&ui_print_header(undef, $text{'index_title'}, "", undef, 0, 1);

my @users = &acl::list_users();
my ($user) = grep { $_->{'name'} eq $base_remote_user } @users;
my $locale_auto = &parse_accepted_language();

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
	my $glang = $locale_auto ||
		    safe_language($gconfig{"lang"}) || $default_lang;
	my $ulang = safe_language($user->{'lang'});
	my @langs = &list_languages();
	my ($linfo) = grep { $_->{'lang'} eq $glang } @langs;
	my ($ulinfo);
	if ($ulang) {
		($ulinfo) = grep { $_->{'lang'} eq $ulang } @langs;
		}
	my $ulangused = ($ulang && $ulang ne $glang);
	my $ulangauto = $user->{'langauto'};
	my $ulangneutral = $user->{'langneutral'};
	if (!defined($user->{'langauto'})) {
		if ($ulangused) {
			$ulangauto = $ulinfo->{'auto'};
			}
		else {
			$ulangauto = defined($gconfig{"langauto"}) ? 
				$gconfig{"langauto"} : $linfo->{'auto'};
			}
		}
	if (!defined($user->{'langneutral'}) && $ulangused) {
		$ulangneutral = $ulinfo->{'neutral'};
		}
	my $selectjs = <<EOF;
<script>
(function () {
    const select = document.querySelector('select[name="lang"]'),
          span = document.querySelector('span[data-neutral]'),
	  checkbox = document.querySelector('input[name="langneutral"]');
    const update = function() {
        const selected = select.options[select.selectedIndex],
              show = selected.getAttribute('data-neutral') === '1';
        span.style.visibility = show ? 'visible' : 'hidden';
	if (!show) checkbox.checked = false;
    }
    update();
    select.addEventListener('change', update);
})();
</script>
EOF
	print &ui_table_row($text{'index_lang'},
		&ui_radio("lang_def", $ulang ? 0 : 1,
			  [ [ 1, &text('index_langglobal2', $linfo->{'desc'},
				       $linfo->{'lang'})."<br>" ],
			    [ 0, $text{'index_langset'} ] ])." ".
		&ui_select("lang", $ulang,
			   [ map { [ $_->{'lang'},
				     $_->{'desc'},
				     "data-neutral='$_->{'neutral'}'" ] }
			         &list_languages() ]) .
			"<wbr data-group><span data-nowrap>&nbsp;&nbsp;". 
				&ui_checkbox("langauto", 1,
				    $text{'langauto_include'}, $ulangauto).
				"&nbsp;&nbsp;<span data-neutral>".
				&ui_checkbox("langneutral", 1,
				    $text{'langneutral_include'}, $ulangneutral).
				"</span>".
			"</span>$selectjs",
		undef, [ "valign=top","valign=top" ]);
	}

# Old datetime format or a new locale
if ($access{'locale'}) {
	&foreign_require('webmin');
	eval "use DateTime; use DateTime::Locale; use DateTime::TimeZone;";
	if (!$@ && $] > 5.011) {
        my $locales = &list_locales();
        my %localesrev = reverse %{$locales};
        my $locale = $locale_auto || $gconfig{'locale'} ||
		&get_default_system_locale();
        print &ui_table_row($text{'index_locale'},
        	&ui_radio("locale_def", defined($user->{'locale'}) ? 0 : 1,
        		  [ [ 1, &text('index_localeglobal2',
			  	$locales->{$locale}, $locale)."<br>" ],
        		    [ 0, $text{'index_localeset'} ] ])." ".
        	&ui_select("locale", $user->{'locale'},
        		[ map { [ $localesrev{$_}, $_ ] }
				sort values %{$locales} ] ), 
        	undef, [ "valign=top","valign=top" ]);
        }
	else {
		my %wtext = &load_language('webmin');
		print &ui_table_row($text{'index_locale2'},
			&ui_radio("dateformat_def",
				defined($user->{'dateformat'}) ? 0 : 1,
				  [ [ 1, &text('index_dateformatglobal2',
				  	$gconfig{'dateformat'} ||
					"dd/mon/yyyy")."<br>" ],
				    [ 0, $text{'index_dateformatset'} ] ])." ".
			&ui_select("dateformat", $user->{'dateformat'} ||
				   "dd/mon/yyyy",
				[ map { [ $_, $wtext{'lang_dateformat_'.$_} ] }
                           @webmin::webmin_date_formats ] ), 
			undef, [ "valign=top","valign=top" ]);
        }
	}

if ($access{'theme'}) {
	# Show personal theme
	my %tinfo = ();
	my $tname;
	if ($gconfig{'theme'}) {
		my ($gtheme, $goverlay) = split(/\s+/, $gconfig{'theme'});
		%tinfo = &webmin::get_theme_info($gtheme);
		$tname = $tinfo{'desc'};
		}
	else {
		$tname = $text{'index_themedef'};
		}
	my @all = &webmin::list_visible_themes($user->{'theme'});
	my @themes = grep { !$_->{'overlay'} } @all;
	my @overlays = grep { $_->{'overlay'} } @all;

	# Main theme
	my $tconf_link;
	if ($user->{'theme'} && $user->{'theme'} eq $tinfo{'dir'} &&
	    $tinfo{'config_link'}) {
		$tconf_link = &ui_tag('span', &ui_link(
			"@{[&get_webprefix()]}/$tinfo{'config_link'}",
			&ui_tag('span', '⚙', 
				{ class => 'theme-config-char',
				  title => $text{'themes_configure'} }),
			'text-link'), { style => 'position: relative;' });
		}
	print &ui_table_row($text{'index_theme'},
		&ui_radio("theme_def", defined($user->{'theme'}) ? 0 : 1,
			  [ [ 1, &text('index_themeglobal', $tname)."<br>" ],
			    [ 0, $text{'index_themeset'} ] ])." ".
		&ui_select("theme", $user->{'theme'},
			[ !$user->{'theme'}
				? [ '', $text{'index_themedef'} ]
				: (),
			  map { [ $_->{'dir'}, $_->{'desc'} ] }
			      @themes ]).$tconf_link,
		undef, [ "valign=top","valign=top" ]);

	# Overlay, if any
	if (@overlays) {
		print &ui_table_row($text{'index_overlay'},
			&ui_select("overlay", $user->{'overlay'},
				[ [ '', $text{'index_overlaydef'} ],
				  map { [ $_->{'dir'}, $_->{'desc'} ] }
				      @overlays ]),
			undef, [ "valign=middle","valign=middle" ]);
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
		&ui_password("pass2", undef, 20), undef,
			[ "valign=top","valign=middle" ]);
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'index_ok'} ] ]);

&ui_print_footer("/", $text{'index'});

