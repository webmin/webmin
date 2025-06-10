#!/usr/local/bin/perl
# Show a form for changing the theme overlay

require "gray-theme/gray-theme-lib.pl";

# Get the user and themes
&foreign_require("acl", "acl-lib.pl");
@overlays = &list_virtualmin_theme_overlays();
($user) = grep { $_->{'name'} eq $base_remote_user } &acl::list_users();
$user || &error($text{'overlay_euser'});
$overlay = $current_themes[1];

&ui_print_header(undef, $text{'overlay_title'}, "");

print &ui_form_start("save_overlay.cgi");
print $text{'overlay_desc'},"<p>\n";
print "<b>$text{'overlay_msg'}</b>\n";
print &ui_select("overlay", $overlay,
	 [ [ "", $text{'overlay_none'} ],
	   map { [ $_->{'dir'}, $_->{'desc'} ] } @overlays ]),"<br>\n";
print &ui_form_end([ [ undef, $text{'overlay_ok'} ] ]);

&ui_print_footer("right.cgi", $text{'right_return'});

