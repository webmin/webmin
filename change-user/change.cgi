#!/usr/local/bin/perl
# change.cgi
# Make all the changes, and re-direct to / in case the theme has changed

use strict;
use warnings;
require './change-user-lib.pl';
our (%text, %in, %gconfig, $base_remote_user, %access);
&ReadParse();

&ui_print_unbuffered_header(undef, $text{'change_title'}, "");

my @users = &acl::list_users();
my ($user) = grep { $_->{'name'} eq $base_remote_user } @users;
my $oldtheme = $user->{'theme'};
my $oldoverlay = $user->{'overlay'};
if (!defined($oldtheme)) {
	($oldtheme, $oldoverlay) = split(/\s+/, $gconfig{'theme'});
	}

# Validate the password
if ($access{'pass'} && &can_change_pass($user) && !$in{'pass_def'}) {
	$in{'pass'} =~ /:/ && &error($text{'change_ecolon'});
	$in{'pass'} eq $in{'pass2'} ||
		&error($text{'change_epass2'});
	my $perr = &acl::check_password_restrictions(
		$user->{'name'}, $in{'pass'});
	&error(&text('change_epass', $perr)) if ($perr);
	}

# Parse custom language
if ($access{'lang'}) {
	if ($in{'lang_def'}) {
		$user->{'lang'} = undef;
		}
	else {
		$user->{'lang'} = $in{'lang'};
		}
	}

# Parse custom theme and possibly overlay
my ($newoverlay, $newtheme);
if ($access{'theme'}) {
	if ($in{'theme_def'}) {
		$user->{'theme'} = undef;
		}
	else {
		$user->{'theme'} = $in{'theme'};
		}
	$newtheme = $user->{'theme'};
	if (!defined($newtheme)) {
		$newtheme = $gconfig{'theme'};
		}

	# Overlay
	if (!$in{'overlay'}) {
		$newoverlay = undef;
		$user->{'overlay'} = undef;
		}
	else {
		$newoverlay = $in{'overlay'};
		$user->{'theme'} || &error($text{'change_eoverlay'});
		my %oinfo = &get_theme_info($in{'overlay'});
		if ($oinfo{'overlays'} &&
		    &indexof($user->{'theme'},
			     split(/\s+/, $oinfo{'overlays'})) < 0) {
			&error($text{'change_eoverlay2'});
			}
		$user->{'overlay'} = $in{'overlay'};
		}
	}

# Parse password change
if ($access{'pass'} && &can_change_pass($user) && !$in{'pass_def'}) {
	$user->{'pass'} = &acl::encrypt_password($in{'pass'});
	$user->{'temppass'} = 0;
	}

if ($access{'theme'} &&
    ($newtheme ne $oldtheme || $newoverlay ne $oldoverlay)) {
        if (defined(&theme_pre_change_theme)) {
                &theme_pre_change_theme();
                }
	}

print "$text{'change_user'}<br>\n";
&acl::modify_user($user->{'name'}, $user);
print "$text{'change_done'}<p>\n";

print "$text{'change_restart'}<br>\n";
&reload_miniserv();
print "$text{'change_done'}<p>\n";

if ($access{'theme'} &&
    ($newtheme ne $oldtheme || $newoverlay ne $oldoverlay)) {
	if (defined(&theme_post_change_theme)) {
		&theme_post_change_theme();
		}
	print "$text{'change_redirect'}<br>\n";
	print &js_redirect("/", "top");
	print "$text{'change_done'}<p>\n";
	}

&ui_print_footer("/", $text{'index'});

