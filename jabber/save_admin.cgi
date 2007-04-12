#!/usr/local/bin/perl
# save_admin.cgi
# Save admin users and autoreply

require './jabber-lib.pl';
&ReadParse();
&error_setup($text{'admin_err'});

$conf = &get_jabber_config();
$session = &find_by_tag("service", "id", "sessions", $conf);
$jsm = &find("jsm", $session);
$admin = &find("admin", $jsm);
if (!$admin) {
	$admin = [ "admin", [ { } ] ];
	}

# Validate and save inputs
foreach $r (split(/\s+/, $in{'read'})) {
	push(@read, [ 'read', [ { }, 0, $r ] ] );
	}
&save_directive($admin, "read", \@read);
foreach $w (split(/\s+/, $in{'write'})) {
	push(@write, [ 'write', [ { }, 0, $w ] ] );
	}
&save_directive($admin, "write", \@write);
if ($in{'reply_def'}) {
	&save_directive($admin, "reply");
	}
else {
	$reply = &find("reply", $admin);
	if (!$reply) {
		$reply = [ "reply", [ { } ] ];
		&save_directive($admin, "reply", [ $reply ] );
		}
	&save_directive($reply, "subject",
			[ [ 'subject', [ { }, 0, $in{'rsubject'} ] ] ]);
	&save_directive($reply, "body",
			[ [ 'body', [ { }, 0, $in{'rbody'} ] ] ]);
	}
@am = @{$admin->[1]};
if (@am > 1) {
	&save_directive($jsm, "admin", [ $admin ]);
	}
else {
	&save_directive($jsm, "admin");
	}

&save_jabber_config($conf);
&redirect("");

