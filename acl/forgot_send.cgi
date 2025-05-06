#!/usr/local/bin/perl
# Actually send the password reset email

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './acl-lib.pl';
our (%in, %text);
&foreign_require("webmin");
&error_setup($text{'forgot_err'});
&ReadParse();
&can_edit_user($in{'user'}) || &error($text{'edit_euser'});
my $wuser = &get_user($in{'user'});
$wuser || &error($text{'edit_egone'});

# Validate inputs
$in{'email'} =~ /^\S+\@\S+$/ || &error($text{'forgot_eemail'});
my $unixuser;
if (defined($in{'unix_def'}) && !$in{'unix_def'}) {
	getpwnam($in{'unix'}) || &error($text{'forgot_eunix'});
	$unixuser = $in{'unix'};
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
&write_file("$main::forgot_password_link_dir/$link{'id'}", \%link);
my $baseurl = &get_webmin_email_url();
my $url = $baseurl.'/forgot.cgi?id='.&urlize($link{'id'});
$url = &theme_forgot_url($baseurl, $link{'id'}, $link{'user'})
	if (defined(&theme_forgot_url));

# Construct and send the email
&foreign_require("mailboxes");
my $msg = &text('forgot_adminmsg', $wuser->{'name'}, $url, $baseurl);
$msg =~ s/\\n/\n/g;
$msg = join("\n", &mailboxes::wrap_lines($msg, 75))."\n";
my $username = $unixuser || $wuser->{'name'};
my $subject = &text('forgot_subject', $username);
&mailboxes::send_text_mail(&mailboxes::get_from_address(),
			   $in{'email'},
			   undef,
			   $subject,
			   $msg);

&webmin_log("forgot", "admin", undef,
	    { 'user' => $unixuser || $wuser->{'name'},
	      'unix' => $unixuser ? 1 : 0,
	      'email' => $in{'email'} });
&redirect("");

