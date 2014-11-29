
use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
do 'squid-lib.pl';

# useradmin_create_user(&details)
# Create a new Squid user
sub useradmin_create_user
{
my ($uinfo) = @_;
return if (!$config{'sync_create'});
if ($config{'crypt_conf'} == 1) {
        eval "use MD5";
	return if ($@);
        }
return if ($uinfo->{'passmode'} != 3);

my $user = $uinfo->{'user'};
my $pass = $uinfo->{'plainpass'};

my $conf = &get_config();
my $file = &get_auth_file($conf);
return if (!$file);

&lock_file($file);
my @users = &list_auth_users($file);

my ($same) = grep { $_->{'user'} eq $user } @users;
return if ($same);
$pass = &encryptpwd($pass, undef);
my $fh = "USER";
&open_tempfile($fh, ">>$file");
&print_tempfile($fh, "$user:$pass\n");
&close_tempfile($fh);
&unlock_file($file);

&restart_squid();
}

# useradmin_delete_user(&details)
# Delete this Squid user if in sync
sub useradmin_delete_user
{
my ($uinfo) = @_;
return if (!$config{'sync_delete'});

my $name = $uinfo->{'user'};

my $conf = &get_config();
my $file = &get_auth_file($conf);
return if (!$file);

&lock_file($file);
my @users = &list_auth_users($file);
my $user;
foreach my $u (@users) {
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
my ($uinfo) = @_;
return if (!$config{'sync_modify'});
if ($config{'crypt_conf'} == 1) {
        eval "use MD5";
	return if ($@);
        }
my $conf = &get_config();
my $file = &get_auth_file($conf);
return if (!$file);

my $name = $_[0]->{'user'};
my $oldname = $_[1]->{'user'};
my $pass = $_[0]->{'plainpass'};
return if ($oldname && $name eq $oldname && $_[0]->{'passmode'} == 4);

&lock_file($file);
my @users = &list_auth_users($file);
my $user;
foreach my $u (@users) {
        if ($u->{'user'} eq $oldname) {
		$user = $u;
		last;
		}
        }
# In the passwd file?
return if (!$user);

my $cmt = $user->{'enabled'} ? "" : "#";
$pass = $uinfo->{'passmode'} == 3 ? &encryptpwd($pass, undef)
				  : $user->{'pass'};
&replace_file_line($file, $user->{'line'},
		   "$cmt$name:$pass\n");
&unlock_file($file);

&restart_squid();
}

sub encryptpwd {
  my ($pwd, $salt) = @_;
  if ($config{'crypt_conf'}) {
    my $encryptpwd = new MD5;
    $encryptpwd->add($pwd);
    $pwd = encode_base64($encryptpwd->hexdigest());
    chomp($pwd);
    $pwd = "\$$pwd\$";
    return $pwd;
    }
    else {
      $salt ||= substr(time(), -2);
      my $pwd = &unix_crypt($pwd, $salt);
      return $pwd;
      }
  }

sub restart_squid
{
&system_logged("$config{'squid_path'} -f $config{'squid_conf'} -k reconfigure >/dev/null 2>&1 </dev/null");
}

1;

