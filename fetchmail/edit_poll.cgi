#!/usr/local/bin/perl
# edit_poll.cgi
# Display one server polled by fetchmail

require './fetchmail-lib.pl';
&ReadParse();
if ($config{'config_file'}) {
	$file = $config{'config_file'};
	}
else {
	&can_edit_user($in{'user'}) || &error($text{'poll_ecannot'});
	@uinfo = getpwnam($in{'user'});
	$file = "$uinfo[7]/.fetchmailrc";
	$uheader = &text('poll_foruser', "<tt>$in{'user'}</tt>");
	}

if ($in{'new'}) {
	&ui_print_header($uheader, $text{'poll_create'}, "");
	}
else {
	&ui_print_header($uheader, $text{'poll_edit'}, "");
	@conf = &parse_config_file($file);
	$poll = $conf[$in{'idx'}];
	}

# Show server options
print &ui_form_start("save_poll.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});
print &ui_hidden("file", $file);
print &ui_hidden("user", $in{'user'});
print &ui_table_start($text{'poll_header'}, "width=100%", 2);

# Server to poll
print &ui_table_row($text{'poll_poll'},
	&ui_textbox("poll", $poll->{'poll'}, 30));

# Polling enabled?
print &ui_table_row($text{'poll_skip'},
	&ui_yesno_radio("skip", $poll->{'skip'} ? 1 : 0,
			[ [ 0, $text{'yes'} ],
			  [ 1, $text{'no'} ] ]));

# Server to connect via
print &ui_table_row($text{'poll_via'},
	&ui_opt_textbox("via", $poll->{'via'}, 30, $text{'poll_via_def'}), 3);

# Protocol
print &ui_table_row($text{'poll_proto'},
	&ui_select("proto", lc($poll->{'proto'}),
		   [ [ '', $text{'default'} ],
		     map { [ $_, uc($_) ] } ('pop3', 'pop2', 'imap', 'imap-k4', 'imap-gss', 'apop', 'kpop'),
		   ], 1, 0, 1));

# Port number
print &ui_table_row($text{'poll_port'},
	&ui_opt_textbox("port", $poll->{'port'}, 8, $text{'default'}));

# Authentication method
print &ui_table_row($text{'poll_auth'},
	&ui_select("auth", lc($poll->{'auth'}),
		   [ [ '', $text{'default'} ],
		     map { [ $_, uc($_) ] } ('password', 'kerberos_v5', 'kerberos_v4', 'gssapi', 'cram-md5', 'otp', 'ntlm', 'ssh') ],
		   1, 0, 1));

# Interface to depend on
@interface = split(/\//, $poll->{'interface'});
print &ui_table_row($text{'poll_interface'},
	&ui_radio("interface_def", @interface ? 0 : 1,
		  [ [ 1, $text{'poll_interface_def'} ],
		    [ 0, $text{'poll_interface_ifc'} ] ])."\n".
	&ui_textbox("interface", $interface[0], 8)." ".
	$text{'poll_interface_ip'}." ".
	&ui_textbox("interface_net", $interface[1], 15)." / ".
	&ui_textbox("interface_mask", $interface[2], 15));

print &ui_table_end();

# Show user options
@users = @{$poll->{'users'}};
push(@users, undef) if ($in{'new'} || $in{'adduser'});
$i = 0;
foreach $u (@users) {
	print &ui_table_start($text{'poll_uheader'}, "width=100%", 2);

	# IMAP username
	print &ui_table_row($text{'poll_user'},
		&ui_textbox("user_$i", $u->{'user'}, 25));

	# IMAP password
	print &ui_table_row($text{'poll_pass'},
		&ui_password("pass_$i", $u->{'pass'}, 25));

	# Deliver to local users
	print &ui_table_row($text{'poll_is'},
		&ui_textbox("is_$i", join(" ", @{$u->{'is'}}) ||
				     $remote_user, 60));

	# Folder to check
	print &ui_table_row($text{'poll_folder'},
		&ui_opt_textbox("folder_$i", $u->{'folder'}, 15,
				$text{'poll_inbox'}));

	# Leave messages on server?
	my @kopts = ( [ 1, $text{'yes'} ], [ 0, $text{'no'} ],
		      [ '', $text{'default'}." (".$text{'poll_usually'}.")" ] );
	print &ui_table_row($text{'poll_keep'},
		&ui_radio("keep_$i", $u->{'keep'}, \@kopts));

	# Always fetch all?
	print &ui_table_row($text{'poll_fetchall'},
		&ui_radio("fetchall_$i", $u->{'fetchall'}, \@kopts));

	# Connect in SSL mode?
	print &ui_table_row($text{'poll_ssl'},
		&ui_radio("ssl_$i", $u->{'ssl'}, \@kopts));

	# Command to run before and after connecting
	print &ui_table_row($text{'poll_preconnect'},
		&ui_textbox("preconnect_$i", $u->{'preconnect'}, 60));
	print &ui_table_row($text{'poll_postconnect'},
		&ui_textbox("postconnect_$i", $u->{'postconnect'}, 60));

	print &ui_table_end();
	$i++;
	}

if ($in{'new'}) {
	push(@buts, [ undef, $text{'create'} ]);
	}
else {
	push(@buts, [ undef, $text{'save'} ]);
	if (!$in{'adduser'}) {
		push(@buts, [ 'adduser', $text{'poll_adduser'} ]);
		}
	push(@buts, [ 'check', $text{'poll_check'} ]);
	push(@buts, [ 'delete', $text{'delete'} ]);
	}
print &ui_form_end(\@buts);

if (!$fetchmail_config && $config{'view_mode'}) {
	&ui_print_footer("edit_user.cgi?user=$in{'user'}", $text{'user_return'},
			 "", $text{'index_return'});
	}
else {
	&ui_print_footer("", $text{'index_return'});
	}

