#!/usr/local/bin/perl
# save_user.cgi
# Save, create or delete a proxy user

require './squid-lib.pl';
$access{'proxyauth'} || &error($text{'eauth_ecannot'});
&ReadParse();
$conf = &get_config();
$file = &find_config("proxy_auth", $conf)->{'values'}->[0];
&lock_file($file);
@users = &list_auth_users($file);

$user = $users[$in{'index'}];
if ($in{'delete'}) {
	&replace_file_line($file, $user->{'line'});
	}
else {
	$whatfailed = $text{'suser_ftsu'};
	$in{'user'} =~ /^[^:\s]+$/ || &error($text{'suser_emsg1'});
	$salt = substr(time(), -2);
	local ($same) = grep { $_->{'user'} eq $in{'user'} } @users;
	if ($in{'new'}) {
		!$same || &error($text{'suser_etaken'});
		&open_tempfile(FILE, ">>$file");
		&print_tempfile(FILE, $in{'user'},":",&unix_crypt($in{'pass'}, $salt),"\n");
		&close_tempfile(FILE);
		}
	else {
		!$same || $same->{'user'} eq $user->{'user'} ||
			 &error($text{'suser_etaken'});
		$pass = $in{'pass_def'} ? $user->{'pass'}
					: &unix_crypt($in{'pass'}, $salt);
		&replace_file_line($file, $user->{'line'},
				   "$in{'user'}:$pass\n");
		}
	}
&unlock_file($file);
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    'user', $in{'user'} ? $in{'user'} : $user->{'user'});
&redirect("edit_auth.cgi");

