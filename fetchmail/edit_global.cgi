#!/usr/local/bin/perl
# edit_global.cgi
# Edit options for all poll sections in a file

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

&ui_print_header($uheader, $text{'global_title'}, "");

@conf = &parse_config_file($file);
foreach $c (@conf) {
	$poll = $c if ($c->{'defaults'});
	}

# Show default server options
print &ui_form_start("save_global.cgi", "post");
print &ui_hidden("file", $file);
print &ui_hidden("user", $in{'user'});
print &ui_table_start($text{'global_header'}, "width=100%", 2);

# Protocol
print &ui_table_row($text{'poll_proto'},
	&ui_select("proto", lc($poll->{'proto'}),
		   [ [ '', $text{'default'} ],
		     map { [ $_, uc($_) ] } ('pop3', 'pop2', 'imap', 'imap-k4', 'imap-gss', 'apop', 'kpop'),
		   ], 1, 0, 1));

# Port number
print &ui_table_row($text{'poll_port'},
	&ui_opt_textbox("port", $poll->{'port'}, 8, $text{'default'}));

# Network interface to check
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
print &ui_form_end([ [ undef, $text{'save'} ] ]);

if (!$fetchmail_config && $config{'view_mode'}) {
	&ui_print_footer("edit_user.cgi?user=$in{'user'}", $text{'user_return'},
			 "", $text{'index_return'});
	}
else {
	&ui_print_footer("", $text{'index_return'});
	}

