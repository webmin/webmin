#!/usr/local/bin/perl
# Show a form for editing GRUB 2 theme and appearance settings.

use strict;
use warnings;
require './grub2-lib.pl';    ## no critic

our (%text);

&ReadParse();
&error_setup($text{'theme_err'});
&grub2_assert_acl('edit');

my $parsed = &read_grub_defaults();
my $values = $parsed->{'values'};
my $current_theme = &field_value($values->{'GRUB_THEME'});
my $theme_action = $current_theme ne '' ? 'keep' : 'clear';

&ui_print_header(undef, $text{'theme_title'}, "", "theme_mode");

# Theme source is only used when the action selector requests installation.
print &ui_form_start("save_theme.cgi", "post");
print &ui_table_start($text{'defaults_theme_header'}, "width=100%", 2);
print &ui_table_row(
	&hlink($text{'defaults_theme_current'}, "theme"),
	$current_theme ne '' ?
		&ui_tag('tt', &html_escape($current_theme)) :
		$text{'defaults_theme_none'}
);
print &ui_table_row(
	&hlink($text{'defaults_theme_action'}, "theme_mode"),
	&ui_select("theme_mode", $theme_action,
		[
			[ "keep", $text{'defaults_theme_keep'} ],
			[ "install", $text{'defaults_theme_install'} ],
			[ "clear", $text{'defaults_theme_clear'} ],
		])
);
print &ui_table_row(
	&hlink($text{'defaults_theme_source'}, "theme_source"),
	&ui_textbox("theme_source", "", 60).
	" ".&file_chooser_button("theme_source").
	&ui_tag('div', &ui_note($text{'defaults_theme_note'}, 0))
);
print &ui_table_row(
	&hlink($text{'defaults_terminal_output'}, "terminal_output"),
	&ui_select("terminal_output",
		   &field_value($values->{'GRUB_TERMINAL_OUTPUT'}),
		[
			[ "", $text{'defaults_keep'} ],
			[ "console", $text{'defaults_terminal_console'} ],
			[ "gfxterm", $text{'defaults_terminal_gfxterm'} ],
			[ "gfxterm console",
			  $text{'defaults_terminal_gfxterm_console'} ],
			[ "serial", $text{'defaults_terminal_serial'} ],
		])
);
print &ui_table_row(
	&hlink($text{'defaults_gfxmode'}, "gfxmode"),
	&gfxmode_select(&field_value($values->{'GRUB_GFXMODE'}))
);
print &ui_table_row(
	&hlink($text{'defaults_background'}, "background"),
	&ui_textbox("background", &field_value($values->{'GRUB_BACKGROUND'}), 60).
	" ".&file_chooser_button("background").
	&ui_tag('div', &ui_note($text{'defaults_background_note'}, 0))
);
print &ui_table_row(
	&hlink($text{'defaults_color_normal'}, "color_normal"),
	&color_pair_select("color_normal", $values->{'GRUB_COLOR_NORMAL'},
			   "white", "black")
);
print &ui_table_row(
	&hlink($text{'defaults_color_highlight'}, "color_highlight"),
	&color_pair_select("color_highlight",
			   $values->{'GRUB_COLOR_HIGHLIGHT'},
			   "black", "light-gray")
);
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);
print &color_mode_script();

&ui_print_footer("index.cgi", $text{'index_return'});

# color_pair_select(name, value, default-foreground, default-background)
# Returns foreground/background selectors for GRUB menu colors.
sub color_pair_select
{
my ($name, $value, $default_fg, $default_bg) = @_;
my ($fg, $bg) = ($default_fg, $default_bg);
my $mode = "default";
if (defined($value) && $value =~ /^([^\/]+)\/([^\/]+)\z/) {
	# Existing GRUB colors are stored as foreground/background pairs.
	($fg, $bg) = ($1, $2);
	$mode = "set";
	}
return &ui_select($name."_mode", $mode, [
		[ "default", $text{'defaults_color_default'} ],
		[ "set", $text{'defaults_color_custom'} ],
	]).
       &ui_tag('span',
	       "&nbsp;".&html_escape($text{'defaults_color_text'})." ".
	       &ui_select($name."_fg", $fg, &color_options())." ".
	       "&nbsp;".&html_escape($text{'defaults_color_background'}).
	       " ".&ui_select($name."_bg", $bg, &color_options()),
	       {
		       'id' => $name."_custom_colors",
		       'style' => 'white-space: nowrap; visibility: '.
				  ($mode eq 'set' ? 'visible' : 'hidden').';',
	       });
}

# color_mode_script()
# Shows foreground/background selectors only for custom color pairs.
sub color_mode_script
{
return &ui_tag('script', <<'EOF', { 'type' => 'application/javascript' });
function grub2_color_mode_select(name) {
	// Theme reloads may replace IDs; fall back to the stable field name.
	return document.getElementById(name + '_mode') ||
	       document.querySelector('select[name="' + name + '_mode"]');
}
function grub2_color_mode_changed(name) {
	const mode = grub2_color_mode_select(name);
	const custom = document.getElementById(name + '_custom_colors');
	if (!mode || !custom) {
		return;
	}
	// Visibility avoids layout jumps when a custom color pair is enabled.
	custom.style.visibility = mode.value === 'set' ? 'visible' : 'hidden';
}
function grub2_color_modes_refresh() {
	grub2_color_mode_changed('color_normal');
	grub2_color_mode_changed('color_highlight');
}
document.addEventListener('change', function(event) {
	const target = event.target;
	if (!target || !target.name) {
		return;
	}
	if (target.name === 'color_normal_mode') {
		grub2_color_mode_changed('color_normal');
	}
	else if (target.name === 'color_highlight_mode') {
		grub2_color_mode_changed('color_highlight');
	}
});
grub2_color_modes_refresh();
document.addEventListener('DOMContentLoaded', grub2_color_modes_refresh);
if (window.MutationObserver && document.body) {
	// Re-apply after theme JavaScript re-renders form controls.
	new MutationObserver(grub2_color_modes_refresh).observe(document.body, {
		childList: true,
		subtree: true
	});
}
EOF
}

# gfxmode_select(value)
# Returns a dropdown of common GRUB graphical resolutions.
sub gfxmode_select
{
my ($value) = @_;
return &ui_select("gfxmode", $value, &gfxmode_options(), undef, undef, 1);
}

# gfxmode_options()
# Returns common GRUB graphical resolution choices.
sub gfxmode_options
{
return [
	[ "", $text{'defaults_gfxmode_default'} ],
	[ "auto", $text{'defaults_gfxmode_auto'} ],
	map { [ $_, $_ ] } qw(
		640x480
		800x600
		1024x768
		1280x720
		1280x800
		1366x768
		1440x900
		1600x900
		1680x1050
		1920x1080
		1920x1200
		2560x1440
		3840x2160
	),
];
}

# color_options()
# Returns GRUB color choices.
sub color_options
{
return [
	map { [ $_, $text{'color_'.$_} || $_ ] } &grub2_color_names()
];
}

# field_value(value, [default])
# Returns a form value without treating the string 0 as empty.
sub field_value
{
my ($value, $default) = @_;
return defined($value) ? $value : ($default || '');
}
