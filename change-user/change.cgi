#!/usr/local/bin/perl
# change.cgi
# Make all the changes, and re-direct to / in case the theme has changed

require './change-user-lib.pl';
&ReadParse();

&ui_print_unbuffered_header(undef, $text{'change_title'}, "");

@users = &acl::list_users();
($user) = grep { $_->{'name'} eq $base_remote_user } @users;
$oldtheme = $user->{'theme'};
if (!defined($oldtheme)) {
	$oldtheme = $gconfig{'theme'};
	}

# Validate the password
if ($access{'pass'} && &can_change_pass($user) && !$in{'pass_def'}) {
	$in{'pass'} =~ /:/ && &error($text{'change_ecolon'});
	$perr = &acl::check_password_restrictions(
		$user->{'name'}, $in{'pass'});
	&error(&text('change_epass', $perr)) if ($perr);
	}

print "$text{'change_user'}<br>\n";
if ($access{'lang'}) {
	if ($in{'lang_def'}) {
		$user->{'lang'} = undef;
		}
	else {
		$user->{'lang'} = $in{'lang'};
		}
	}
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
	}
if ($access{'pass'} && &can_change_pass($user) && !$in{'pass_def'}) {
	$user->{'pass'} = &acl::encrypt_password($in{'pass'});
	$user->{'temppass'} = 0;
	}
&acl::modify_user($user->{'name'}, $user);
print "$text{'change_done'}<p>\n";

print "$text{'change_restart'}<br>\n";
&reload_miniserv();
print "$text{'change_done'}<p>\n";

if ($access{'theme'} && $newtheme ne $oldtheme) {
	print "$text{'change_redirect'}<br>\n";
	print "<script>\n";
	print "window.parent.location = '/';\n";
	print "</script>\n";
	print "$text{'change_done'}<p>\n";
	}

&ui_print_footer("/", $text{'index'});

