#!/usr/local/bin/perl
# Update the theme overlay

require "gray-theme/gray-theme-lib.pl";
&ReadParse();
($gtheme) = split(/\s+/, $gconfig{'theme'});

# Get and modify the user
&foreign_require("acl", "acl-lib.pl");
($user) = grep { $_->{'name'} eq $base_remote_user } &acl::list_users();
$user || &error($text{'overlay_euser'});
if ($in{'overlay'}) {
	$user->{'theme'} = $current_theme;
	}
elsif ($gtheme eq $current_theme) {
	# No need for user-specific theme
	delete($user->{'theme'});
	}
$user->{'overlay'} = $in{'overlay'};
&acl::modify_user($user->{'name'}, $user);

# Refresh the page
&ui_print_header(undef, $text{'overlay_title'}, "");

print $text{'overlay_webmin'},"<br>\n";
&reload_miniserv();
print $text{'overlay_done'},"<p>\n";

print $text{'overlay_refresh'},"<br>\n";
print &js_redirect("/", "top");
print $text{'overlay_done'},"<p>\n";

&ui_print_footer("right.cgi", $text{'right_return'});
