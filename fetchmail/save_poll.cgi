#!/usr/local/bin/perl
# save_poll.cgi
# Update, create or delete a server to poll

require './fetchmail-lib.pl';
&ReadParse();
&error_setup($text{'poll_err'});
if ($config{'config_file'}) {
	$file = $config{'config_file'};
	}
else {
	&can_edit_user($in{'user'}) || &error($text{'poll_ecannot'});
	@uinfo = getpwnam($in{'user'});
	$file = "$uinfo[7]/.fetchmailrc";
	}
@conf = &parse_config_file($file);
if (!$in{'new'}) {
	$poll = $conf[$in{'idx'}];
	}

&lock_file($file);
if ($in{'adduser'}) {
	# Go back to the edit form
	&redirect("edit_poll.cgi?file=$file&idx=$in{'idx'}&adduser=1&user=$in{'user'}");
	exit;
	}
elsif ($in{'check'}) {
	# Go to the mail checking CGI
	&redirect("check.cgi?file=$file&idx=$in{'idx'}&adduser=1&user=$in{'user'}");
	exit;
	}
elsif ($in{'delete'}) {
	# Just delete the poll
	&delete_poll($poll, $file);
	}
else {
	# Validate poll inputs
	$in{'poll'} =~ /^\S+$/ || &error($text{'poll_epoll'});
	$in{'via_def'} || &check_host($in{'via'}) ||
		&error($text{'poll_evia'});
	!$in{'via_def'} || &check_host($in{'poll'}) ||
		&error($text{'poll_epoll'});
	$in{'port_def'} || $in{'port'} =~ /^\d+$/ ||
		&error($text{'poll_eport'});
	if (!$in{'interface_def'}) {
		$in{'interface'} =~ /^\S+$/ || &error($text{'poll_einterface'});
		&check_ipaddress($in{'interface_net'}) ||
			&error($text{'poll_enet'});
		&check_ipaddress($in{'interface_mask'}) ||
		    !$in{'interface_mask'} ||
			&error($text{'poll_emask'});
		}

	# Create the poll structure
	$poll->{'poll'} = $in{'poll'};
	$poll->{'skip'} = $in{'skip'};
	$poll->{'via'} = $in{'via_def'} ? undef : $in{'via'};
	$poll->{'proto'} = $in{'proto'};
	$poll->{'auth'} = $in{'auth'};
	$poll->{'port'} = $in{'port_def'} ? undef : $in{'port'};
	if ($in{'interface_def'}) {
		delete($poll->{'interface'});
		}
	else {
		local @interface = ( $in{'interface'}, $in{'interface_net'} );
		push(@interface, $in{'interface_mask'})
			if ($in{'interface_mask'});
		$poll->{'interface'} = join("/", @interface);
		}

	# Validate user inputs
	for($i=0; defined($in{"user_$i"}); $i++) {
		$user = $poll->{'users'}->[$i];
		next if (!$in{"user_$i"});
		$in{"user_$i"} =~ /^\S*$/ || &error($text{'poll_euser'});
		$user->{'user'} = $in{"user_$i"};
		$user->{'pass'} = $in{"pass_$i"};
		local @is = split(/\s+/, $in{"is_$i"});
		$user->{'is'} = \@is;
		$user->{'keep'} = $in{"keep_$i"};
		$user->{'fetchall'} = $in{"fetchall_$i"};
		if ($in{"keep_$i"} == 1 && $in{"fetchall_$i"} == 1) {
			&error($text{'poll_eboth'});
			}
		$user->{'ssl'} = $in{"ssl_$i"};
		$user->{'preconnect'} = $in{"preconnect_$i"};
		$user->{'postconnect'} = $in{"postconnect_$i"};
		push(@users, $user);
		}
	$poll->{'users'} = \@users;

	if ($in{'new'}) {
		&create_poll($poll, $file);
		if ($in{'user'} && $< == 0) {
			local @uinfo = getpwnam($in{'user'});
			&system_logged("chown $uinfo[2]:$uinfo[3] $file");
			}
		&system_logged("chmod 700 $file");
		}
	else {
		&modify_poll($poll, $file);
		}
	}

&unlock_file($file);
&webmin_log($in{'new'} ? 'create' : $in{'delete'} ? 'delete' : 'modify',
	    'poll', $poll->{'poll'},
	    $config{'config_file'} ? { 'file' => $file }
				   : { 'user' => $in{'user'} } );
&redirect(!$fetchmail_config && $config{'view_mode'} ?
	"edit_user.cgi?user=$in{'user'}" : "");

sub check_host
{
return 1 if (&to_ipaddress($_[0]) || &to_ip6address($_[0]));
return 0 if (&to_ipaddress("www.webmin.com"));	# only fail if we are online
return 1;
}

