#!/usr/local/bin/perl
# save_nuser.cgi
# Save, create or delete a proxy user

require './squid-lib.pl';
if ($config{'crypt_conf'} == 1) {
	eval "use MD5";
	if ($@) {
        	&error(&text('eauth_nomd5', $module_name));
		}
	}

$access{'proxyauth'} || &error($text{'eauth_ecannot'});
&ReadParse();
$conf = &get_config();
$file = &get_auth_file($conf);
&lock_file($file);
@users = &list_auth_users($file);

$user = $users[$in{'index'}];
if ($in{'delete'}) {
	&replace_file_line($file, $user->{'line'});
	}
else {
	$whatfailed = $text{'suser_ftsu'};
	$in{'user'} =~ /^[^:\s]+$/ || &error($text{'suser_emsg1'});
	local ($same) = grep { $_->{'user'} eq $in{'user'} } @users;
	local $cmt = $in{'enabled'} ? "" : "#";
	if ($in{'new'}) {
		!$same || &error($text{'suser_etaken'});
		$pass = &encryptpwd($in{'pass'}, $salt);
		&open_tempfile(FILE,">>$file");
		&print_tempfile(FILE, "$cmt$in{'user'}:$pass\n");
		&close_tempfile(FILE);
		}
	else {
		!$same || $same->{'user'} eq $user->{'user'} ||
			 &error($text{'suser_etaken'});
		$pass = $in{'pass_def'} ? $user->{'pass'}
					: &encryptpwd($in{'pass'}, $salt);
		&replace_file_line($file, $user->{'line'},
				   "$cmt$in{'user'}:$pass\n");
		}
	}
&unlock_file($file);
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    'user', $in{'user'} ? $in{'user'} : $user->{'user'});
&redirect("edit_nauth.cgi");

sub encryptpwd {
  if ($config{'crypt_conf'}) {
    my $pwd = $_[0];
    my $encryptpwd = new MD5;
    $encryptpwd->add($pwd);
    $pwd = encode_base64($encryptpwd->hexdigest());
    chomp($pwd);
    $pwd = "\$$pwd\$";
    return $pwd;
    }
    else {
      $salt = substr(time(), -2);
      my $pwd = &unix_crypt($_[0], $_[1]);
      return $pwd;
      }
  }
