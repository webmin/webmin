do 'squid-lib.pl';

# useradmin_create_user(&details)
# Create a new Squid user
sub useradmin_create_user
{
return if (!$config{'sync_create'});
if ($config{'crypt_conf'} == 1) {
        eval "use MD5";
	return if ($@);
        }
return if ($_[0]->{'passmode'} != 3);

local $user = $_[0]->{'user'};
local $pass = $_[0]->{'plainpass'};

local $conf = &get_config();
local $file = &get_auth_file($conf);
return if (!$file);

&lock_file($file);
local @users = &list_auth_users($file);

local ($same) = grep { $_->{'user'} eq $user } @users;
return if ($same);
$pass = &encryptpwd($pass, $salt);
open(FILE,">>$file");
print FILE "$user:$pass\n";
close(FILE);
&unlock_file($file);

&restart_squid();
}

# useradmin_delete_user(&details)
# Delete this Squid user if in sync
sub useradmin_delete_user
{
return if (!$config{'sync_delete'});

local $name = $_[0]->{'user'};

local $conf = &get_config();
local $file = &get_auth_file($conf);
return if (!$file);

&lock_file($file);
local @users = &list_auth_users($file);
local $user;
foreach $u (@users) {
	if ($u->{'user'} eq $name) {
		$user = $u;
		last;
		}
	}
# In the passwd file?
return if (!$user);

&replace_file_line($file, $user->{'line'});
&unlock_file($file);

&restart_squid();
}

# useradmin_modify_user(&details)
# Update this users password if in sync
sub useradmin_modify_user
{
return if (!$config{'sync_modify'});
if ($config{'crypt_conf'} == 1) {
        eval "use MD5";
	return if ($@);
        }
local $conf = &get_config();
local $file = &get_auth_file($conf);
return if (!$file);

local $name = $_[0]->{'user'};
local $oldname = $_[1]->{'user'};
local $pass = $_[0]->{'plainpass'};
return if ($name eq $oldname && $_[0]->{'passmode'} == 4);

&lock_file($file);
local @users = &list_auth_users($file);
local $user;
foreach $u (@users) {
        if ($u->{'user'} eq $oldname) {
		$user = $u;
		last;
		}
        }
# In the passwd file?
return if (!$user);

local $cmt = $user->{'enabled'} ? "" : "#";
$pass = $_[0]->{'passmode'} == 3 ? &encryptpwd($pass, $salt)
				 : $user->{'pass'};
&replace_file_line($file, $user->{'line'},
		   "$cmt$name:$pass\n");
&unlock_file($file);

&restart_squid();
}

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

sub restart_squid
{
&system_logged("$config{'squid_path'} -f $config{'squid_conf'} -k reconfigure >/dev/null 2>&1 </dev/null");
}

1;

