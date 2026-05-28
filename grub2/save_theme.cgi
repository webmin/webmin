#!/usr/local/bin/perl
# Save GRUB 2 theme and appearance settings.

use strict;
use warnings;
require './grub2-lib.pl';    ## no critic

our (%in, %text);

&ReadParse();
&error_setup($text{'theme_err'});
my %access = &get_module_acl();
&error("$text{'eacl_np'} $text{'eacl_pedit'}") if (!$access{'edit'});

my $parsed = &read_grub_defaults();
my $current_values = $parsed->{'values'};
my %updates;

# Terminal output is constrained because themes require graphical output.
my %terminal_outputs = map { $_ => 1 }
	('', 'console', 'gfxterm', 'gfxterm console', 'serial');
$in{'terminal_output'} = '' if (!defined($in{'terminal_output'}));
&error($text{'defaults_eterminal_output'})
	if (!$terminal_outputs{$in{'terminal_output'}});
$updates{'GRUB_TERMINAL_OUTPUT'} =
	$in{'terminal_output'} eq '' ? undef : $in{'terminal_output'};

# Graphics mode is a small GRUB grammar, not a general shell value.
$in{'gfxmode'} = '' if (!defined($in{'gfxmode'}));
my $gerr = &grub2_validate_gfxmode($in{'gfxmode'});
&error($gerr) if ($gerr);
$updates{'GRUB_GFXMODE'} = $in{'gfxmode'} eq '' ? undef : $in{'gfxmode'};

# Theme mode decides whether a source is installed, kept, or explicitly unset.
my %theme_modes = map { $_ => 1 } qw(keep install clear);
$in{'theme_mode'} = 'keep' if (!defined($in{'theme_mode'}));
&error($text{'defaults_etheme_mode'}) if (!$theme_modes{$in{'theme_mode'}});
if ($in{'theme_mode'} eq 'install') {
	# Refuse a graphical theme if the pending terminal output is console-only.
	my $requested_terminal_output =
		defined($updates{'GRUB_TERMINAL_OUTPUT'}) ?
		$updates{'GRUB_TERMINAL_OUTPUT'} :
		$current_values->{'GRUB_TERMINAL_OUTPUT'};
	if (defined($requested_terminal_output) &&
	    $requested_terminal_output eq 'console') {
		&error($text{'defaults_etheme_terminal'});
		}
	my ($theme, $terr) = &grub2_install_theme_source($in{'theme_source'});
	&error($terr) if ($terr);
	$updates{'GRUB_THEME'} = $theme;
	}
elsif ($in{'theme_mode'} eq 'clear') {
	$updates{'GRUB_THEME'} = undef;
	}

# Background images are copied below the configured GRUB boot tree.
$in{'background'} = '' if (!defined($in{'background'}));
if ($in{'background'} eq '') {
	$updates{'GRUB_BACKGROUND'} = undef;
	}
else {
	my ($background, $berr) =
		&grub2_install_background_source($in{'background'});
	&error($berr) if ($berr);
	$updates{'GRUB_BACKGROUND'} = $background;
	}

# Color fields use a mode selector so the default/unset state stays explicit.
foreach my $field (
	[ 'color_normal', 'GRUB_COLOR_NORMAL',
	  $text{'defaults_color_normal'} ],
	[ 'color_highlight', 'GRUB_COLOR_HIGHLIGHT',
	  $text{'defaults_color_highlight'} ],
    )
{
	my ($input, $key, $label) = @$field;
	my $mode = $in{$input.'_mode'} || 'default';
	my $fg = $in{$input.'_fg'} || '';
	my $bg = $in{$input.'_bg'} || '';
	my %colors = map { $_ => 1 } &grub2_color_names();
	if ($mode eq 'default') {
		$updates{$key} = undef;
		}
	elsif ($mode eq 'set' && $colors{$fg} && $colors{$bg}) {
		$updates{$key} = $fg.'/'.$bg;
		}
	else {
		&error(&text('defaults_ecolor', $label));
		}
	}

my $theme = exists($updates{'GRUB_THEME'}) ?
	$updates{'GRUB_THEME'} : $current_values->{'GRUB_THEME'};
my $terminal_output = exists($updates{'GRUB_TERMINAL_OUTPUT'}) ?
	$updates{'GRUB_TERMINAL_OUTPUT'} :
	$current_values->{'GRUB_TERMINAL_OUTPUT'};
# Check the final combined state too, because either field may be unchanged.
if (defined($theme) && $theme ne '' &&
    defined($terminal_output) && $terminal_output eq 'console') {
	&error($text{'defaults_etheme_terminal'});
	}

# Keep the generator script while any color override exists or used to exist.
my $need_color_script =
	(defined($updates{'GRUB_COLOR_NORMAL'}) &&
	 $updates{'GRUB_COLOR_NORMAL'} ne '') ||
	(defined($updates{'GRUB_COLOR_HIGHLIGHT'}) &&
	 $updates{'GRUB_COLOR_HIGHLIGHT'} ne '') ||
	-e &grub2_color_file();

my $err = &save_grub_defaults_values(\%updates);
&error(&text('manual_evalidate', $err)) if ($err);
if ($need_color_script) {
	# The color script reads /etc/default/grub at generation time.
	$err = &grub2_save_color_script();
	&error(&text('manual_evalidate', $err)) if ($err);
	}
&grub2_mark_regenerate_needed();
&webmin_log("theme");
&redirect("index.cgi");
