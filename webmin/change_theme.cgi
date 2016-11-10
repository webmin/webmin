#!/usr/local/bin/perl
# change_theme.cgi
# Change the current webmin theme

require './webmin-lib.pl';
&ReadParse();

&ui_print_header(undef, $text{'themes_title'}, "");

($gtheme, @others) = split(/\s+/, $gconfig{'theme'});

# Call pre-change function
if ($in{'theme'} ne $gtheme) {
	if (defined(&theme_pre_change_theme)) {
		&theme_pre_change_theme();
		}
	}

&lock_file("$config_directory/config");
if ($in{'theme'}) {
	$gconfig{'theme'} = join(" ", $in{'theme'}, @others);
	}
else {
	delete($gconfig{'theme'});
	}
&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");

&lock_file($ENV{'MINISERV_CONFIG'});
&get_miniserv_config(\%miniserv);
if ($in{'theme'}) {
	$miniserv{'preroot'} = join(" ", $in{'theme'}, @others);
	}
else {
	delete($miniserv{'preroot'});
	}
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});
&reload_miniserv();

print "$text{'themes_ok'}<p>\n";

# Call post-change function
if ($in{'theme'} ne $gtheme) {
	if (defined(&theme_post_change_theme)) {
		&theme_post_change_theme();
		}
	}

print &js_redirect("/", "top");

&webmin_log('theme', undef, undef, \%in);
&ui_print_footer("", $text{'index_return'});

