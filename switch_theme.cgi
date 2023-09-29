#!/usr/local/bin/perl
# switch_theme.cgi
# Change the theme for the current user if allowed

BEGIN { push(@INC, "."); };
use WebminCore;

&init_config();
&ReadParse();
my $err = sub {
    &PrintHeader();
    print("<tt>Cannot change theme : $_[0]</tt>\n");
    exit(1);
    };
# Check if allowed to change theme,
# otherwise throw an error
if (!&foreign_available('theme') &&
    !&foreign_available('change-user') &&
    !&foreign_available('webmin') &&
    !&foreign_available('acl')) {
    &$err("You are not allowed to change themes!"); 
    }
# Check if the theme is known
&$err("Theme identification is not known!")
    if (!$in{'theme'} || $in{'theme'} !~ /^[123]$/);
# Check if the remote user is known
&$err("Remote user is not known!") if (!$remote_user);
# Define the theme
my $themes = {
    '1' => 'authentic-theme',
    '2' => 'gray-theme',
    '3' => '' };
my $theme = $themes->{$in{'theme'}};
# Change the theme
$gconfig{"theme_$remote_user"} = $theme;
&write_file("$config_directory/config", \%gconfig);
my %miniserv;
&get_miniserv_config(\%miniserv);
$miniserv{"preroot_$remote_user"} = $theme;
&put_miniserv_config(\%miniserv);
&restart_miniserv();
&redirect(&get_webprefix() . "/");
