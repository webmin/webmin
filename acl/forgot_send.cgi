#!/usr/local/bin/perl
# Actually send the password reset email

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './acl-lib.pl';
our (%in, %text, %gconfig);
&foreign_require("webmin");
&error_setup($text{'forgot_err'});
&ReadParse();
&can_edit_user($in{'user_acc'}) || &error($text{'edit_euser'});
my $wuser = &get_user($in{'user_acc'});
$wuser || &error($text{'edit_egone'});

# Validate inputs
$in{'email_def'} || $in{'email'} =~ /^\S+\@\S+$/ ||
	&error($text{'forgot_eemail'});
my $unixuser;
if ($in{'user'} ne $in{'user_acc'}) {
	&foreign_require("useradmin");
	my ($uinfo) = grep { $_->{'user'} eq $in{'user'} }
			   &useradmin::list_users();
	$uinfo || &error($text{'forgot_eunix'});
	my $sudo = &useradmin::can_user_sudo_root($in{'user'});
	&error($text{'forgot_enosudo'}) if ($sudo < 0);
	&error($text{'forgot_ecansudo'}) if (!$sudo);
	$unixuser = $in{'user'};
	}

# Generate a random ID and tracking file for this password reset
my $now = time();
my %link = ( 'id' => &generate_random_id(),
	     'remote' => $ENV{'REMOTE_ADDR'},
	     'time' => $now,
	     'user' => $wuser->{'name'},
	     'uuser' => $unixuser, );
$link{'id'} || &error($text{'forgot_erandom'});
&make_dir($main::forgot_password_link_dir, 0700);
my $linkfile = $main::forgot_password_link_dir."/".$link{'id'};
&lock_file($linkfile);
&write_file($linkfile, \%link);
&unlock_file($linkfile);
my $baseurl = &get_webmin_email_url();
my $url = $baseurl.'/forgot.cgi?id='.&urlize($link{'id'});
&load_theme_library();
$url = &theme_forgot_url($baseurl, $link{'id'}, $unixuser || $link{'user'})
	if (defined(&theme_forgot_url));

&ui_print_header(undef, $text{'forgot_title'}, "");

my $username = $unixuser || $wuser->{'name'};
if ($in{'email_def'}) {
	# Just show the link
	my $timeout = $gconfig{'passreset_timeout'} || 15;
	print "<p>",&text('forgot_link', $username, $timeout),"</p>\n";

	print "<p><tt>".$url."</tt></p>\n";
	&webmin_log("forgot", "link", undef,
		    { 'user' => $username,
		      'unix' => $unixuser ? 1 : 0 });
	}
else {
	# Construct and send the email
	&foreign_require("mailboxes");
	my $msg = &text('forgot_adminmsg', $wuser->{'name'}, $url, $baseurl);
	$msg =~ s/\\n/\n/g;
	$msg = join("\n", &mailboxes::wrap_lines($msg, 75))."\n";
	my $subject = &text('forgot_subject', $username);
	print &text('forgot_sending',
		    &html_escape($in{'email'}), $username),"<br>\n";
	&mailboxes::send_text_mail(&mailboxes::get_from_address(),
				   $in{'email'},
				   undef,
				   $subject,
				   $msg);
	print $text{'forgot_sent'},"<p>\n";

	&webmin_log("forgot", "admin", undef,
		    { 'user' => $username,
		      'unix' => $unixuser ? 1 : 0,
		      'email' => $in{'email'} });
	}

&ui_print_footer("", $text{'index_return'});

