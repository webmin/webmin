#!/usr/local/bin/perl
# Change the current webmin theme overlay

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'themes_err4'});

# Get the overlay and make sure it is compatible
($gtheme) = split(/\s+/, $gconfig{'theme'});
if ($in{'overlay'}) {
	%oinfo = &get_theme_info($in{'overlay'});
	if ($oinfo{'overlays'} &&
	    &indexof($gtheme, split(/\s+/, $oinfo{'overlays'})) < 0) {
		&error($text{'themes_eoverlay'});
		}
	}

&lock_file("$config_directory/config");
if ($in{'overlay'}) {
	$gconfig{'theme'} = join(" ", $gtheme, $in{'overlay'});
	}
else {
	$gconfig{'theme'} = $gtheme;
	}
&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");

&lock_file($ENV{'MINISERV_CONFIG'});
&get_miniserv_config(\%miniserv);
if ($in{'overlay'}) {
	$miniserv{'preroot'} = join(" ", $gtheme, $in{'overlay'});
	}
else {
	$miniserv{'preroot'} = $gtheme;
	}
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});
&reload_miniserv();

&webmin_log('theme', undef, undef, \%in);
&ui_print_header(undef, $text{'themes_title'}, "");
print "$text{'themes_ok2'}<p>\n";
print &js_redirect("/", "top", 1500);
&ui_print_footer("", $text{'index_return'});

