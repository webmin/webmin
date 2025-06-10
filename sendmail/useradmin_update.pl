
do 'sendmail-lib.pl';
do 'aliases-lib.pl';

%mail_sync = map { $_, 1 } split(/,/, $config{'mail_sync'});

# useradmin_create_user(&details)
sub useradmin_create_user
{
local $dir = $config{'mail_dir'};
if ($dir && -d $dir && $mail_sync{'create'}) {
	local $mf = "$dir/$_[0]->{'user'}";
	if (!-e $mf) {
		open(TOUCH, ">$mf");
		close(TOUCH);
		chown($_[0]->{'uid'}, $_[0]->{'gid'}, $mf);
		}
	}
}

# useradmin_delete_user(&details)
# Delete this user's mail file and remove from any aliases
sub useradmin_delete_user
{
local $dir = $config{'mail_dir'};
if ($dir && -d $dir && $mail_sync{'delete'}) {
	unlink("$dir/$_[0]->{'user'}");
	unlink("$dir/.$_[0]->{'user'}.pop");
	}
local $conf = &get_sendmailcf();
local $afile = &aliases_file($conf);
local @aliases = &list_aliases($afile);
foreach $a (@aliases) {
	return if ($a->{'name'} eq $_[0]->{'user'});
	}
foreach $a (@aliases) {
	local @nv = grep { $_ ne $_[0]->{'user'} } @{$a->{'values'}};
	if (scalar(@nv) != scalar(@{$a->{'values'}})) {
		$a->{'values'} = \@nv;
		&modify_alias($a, $a);
		}
	}
}

# useradmin_modify_user(&details)
sub useradmin_modify_user
{
local $dir = $config{'mail_dir'};
if ($dir && -d $dir && $mail_sync{'modify'}) {
	local $mfile = "$dir/$_[0]->{'olduser'}";
	local @st = stat($mfile);
	if ($st[4] != $_[0]->{'uid'}) {
		chown($_[0]->{'uid'}, $st[5], $mfile);
		}
	if ($_[0]->{'olduser'} ne $_[0]->{'user'} && -r $mfile) {
		&rename_logged($mfile, "$dir/$_[0]->{'user'}");
		}
	}
}

1;

