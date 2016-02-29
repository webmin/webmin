# updown-lib.pl

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

if ($module_info{'usermin'}) {
	# Running under Usermin
	&switch_to_remote_user();
	&create_user_config_dirs();
	$downloads_dir = "$user_module_config_directory/downloads";
	$atjob_cmd = "$user_module_config_directory/download.pl";

	$can_upload = $config{'upload'};
	$can_download = $config{'download'};
	$can_fetch = $config{'fetch'};
	$can_schedule = $config{'background'} && &foreign_check("at");
	$can_background = $config{'background'};
	if ($config{'home_only'}) {
		@can_dirs = ( &resolve_links($remote_user_info[7]),
			      split(/\s+/, $config{'root'}) );
		}
	else {
		@can_dirs = ( "/" );
		}
	@can_dirs = &expand_root_variables(@can_dirs);
	$can_mode = 3;

	$download_dir = $userconfig{'ddir'};
	$download_dir = $remote_user_info[7] if ($download_dir eq "~");
	$upload_dir = $userconfig{'dir'};
	$upload_dir = $remote_user_info[7] if ($upload_dir eq "~");
	$upload_max = $config{'max'};
	$fetch_file = $userconfig{'fetch'};
	$fetch_show = $userconfig{'show'} || 0;
	}
else {
	# Running under Webmin
	$downloads_dir = "$module_config_directory/downloads";
	$atjob_cmd = "$module_config_directory/download.pl";

	%access = &get_module_acl();
	$can_upload = $access{'upload'};
	$can_download = $access{'download'};
	$can_fetch = $access{'fetch'} && !&is_readonly_mode();
	if ($access{'download'} != 2) {
		$can_schedule = &foreign_check("at");
		$can_background = 1;
		}
	if (&supports_users()) {
		$can_mode = $access{'mode'};
		}
	else {
		$can_mode = 3;
		}
	@can_users = split(/\s+/, $access{'users'});
	@can_dirs = split(/\s+/, $access{'dirs'});
	if ($access{'home'}) {
		local @uinfo = getpwnam($remote_user);
		push(@can_dirs, $uinfo[7]) if ($uinfo[7]);
		}

	$download_dir = $config{'ddir_'.$remote_user} || $config{'ddir'};
	$upload_dir = $config{'dir_'.$remote_user} || $config{'dir'};
	$upload_user = $config{'user_'.$remote_user} || $config{'user'};
	$upload_group = $config{'group_'.$remote_group} || $config{'group'};
	$upload_max = $access{'max'};
	$download_user = $config{'duser_'.$remote_user} || $config{'duser'};
	$download_group = $config{'dgroup_'.$remote_group} || $config{'dgroup'};
	$fetch_file = $config{'fetch_'.$remote_user};
	$fetch_show = $config{'show_'.$remote_user} || 0;
	}

# list_downloads()
# Returns a list of downloads currently in progress
sub list_downloads
{
local (@rv, $f);
opendir(DIR, $downloads_dir);
foreach $f (readdir(DIR)) {
	next if ($f !~ /^(\S+)\.down$/);
	local $down = &get_download("$1");
	push(@rv, $down) if ($down);
	}
closedir(DIR);
return @rv;
}

# get_download(id)
sub get_download
{
local %down;
&read_file("$downloads_dir/$_[0].down", \%down) || return undef;
$down{'user'} = getpwuid($down{'uid'});
return \%down;
}

# save_download(&download)
sub save_download
{
$_[0]->{'id'} = time().$$ if (!$_[0]->{'id'});
&lock_file($downloads_dir);
mkdir($downloads_dir, 0755);
&unlock_file($downloads_dir);
&lock_file("$downloads_dir/$_[0]->{'id'}.down");
&write_file("$downloads_dir/$_[0]->{'id'}.down", $_[0]);
&unlock_file("$downloads_dir/$_[0]->{'id'}.down");
}

# delete_download(&download)
sub delete_download
{
&lock_file("$downloads_dir/$_[0]->{'id'}.down");
unlink("$downloads_dir/$_[0]->{'id'}.down");
&unlock_file("$downloads_dir/$_[0]->{'id'}.down");
}

# do_download(&download, &callback, &dests)
# Actually download one or more files, and return undef or any error message
sub do_download
{
local ($i, $error, $msg);
for($i=0; $_[0]->{"url_$i"}; $i++) {
	$error = undef;
	$progress_callback_url = $_[0]->{"url_$i"};
	$progress_callback_count = $i;
	local $path;
	if (-d $_[0]->{'dir'}) {
		local $page = $_[0]->{"page_$i"};
		$page =~ s/\?.*$//;
		if ($page =~ /([^\/]+)$/) {
			$path = "$_[0]->{'dir'}/$1";
			}
		else {
			$path = "$_[0]->{'dir'}/index.html";
			}
		}
	else {
		$path = $_[0]->{'dir'};
		}
	&switch_uid_to($_[0]->{'uid'}, $_[0]->{'gid'});
	$down->{'upto'} = $progress_callback_count;
	if ($_[0]->{"proto_$i"} eq "http" || $_[0]->{"proto_$i"} eq "https") {
		&http_download($_[0]->{"host_$i"},
			       $_[0]->{"port_$i"},
			       $_[0]->{"page_$i"},
			       $path,
			       \$error,
			       $_[1],
			       $_[0]->{"ssl_$i"},
			       $_[0]->{"user_$i"},
			       $_[0]->{"pass_$i"});
		}
	else {
		&ftp_download($_[0]->{"host_$i"},
			      $_[0]->{"page_$i"},
			       $path,
			       \$error,
			       $_[1],
			       $_[0]->{"user_$i"},
			       $_[0]->{"pass_$i"});
		}
	unlink($path) if ($error);
	&switch_uid_back();

	# Add to email message
	$msg .= &text('email_downurl', $_[0]->{"url_$i"})."\n";
	if ($error) {
		$msg .= &text('email_downerr', $error)."\n";
		}
	else {
		local @st = stat($path);
		$msg .= &text('email_downpath', $path)."\n";
		$msg .= &text('email_downsize',&nice_size($st[7]))."\n";
		}
	$msg .= "\n";

	last if ($error);
	push(@{$_[2]}, $path);
	}

# Send status email
if ($down->{'email'}) {
	# Send email when done
	$msg = $text{'email_downmsg'}."\n\n".$msg;
	&send_email_notification(
                        $down->{'email'}, $text{'email_subjectd'}, $msg);
	}

return $error;
}

# can_write_file(file)
# Returns 1 if some path can be written to, 0 if not
sub can_write_file
{
local $d;
foreach $d (@can_dirs) {
	return 1 if (&is_under_directory($d, $_[0]));
	}
return 0;
}

# can_as_user(username)
# Returns 1 if uploading or downloading can be done as some user
sub can_as_user
{
if ($can_mode == 0) {
	return 1;
	}
elsif ($can_mode == 1) {
	return &indexof($_[0], @can_users) != -1;
	}
elsif ($can_mode == 2) {
	return &indexof($_[0], @can_users) == -1;
	}
elsif ($can_mode == 3) {
	return $_[0] eq $remote_user;
	}
else {
	return 0;	# shouldn't happen
	}
}

# in_group(&uinfo, &ginfo)
sub in_group
{
return 1 if ($_[0]->[3] == $_[1]->[2]);
foreach $s (&other_groups($_[0]->[0])) {
	return 1 if ($s eq $_[1]->[2]);
	}
return 0;
}

# switch_uid_to(uid, gid)
# Temporarily sets the effective UID and GID, if appropriate
sub switch_uid_to
{
if ($< == 0 && ($_[0] || $_[1]) && &supports_users()) {
	$old_uid = $>;
	$old_gid = $);
	$) = "$_[1] $_[1]";
	$> = $_[0];
	}
}

# switch_uid_back()
# Undo the switch made by switch_uid_to
sub switch_uid_back
{
if (defined($old_uid)) {
	$> = $old_uid;
	$) = $old_gid;
	$old_uid = $old_gid = undef;
	}
}

# send_email_notification(address, subject, message)
# Send email when some download or upload is complete
sub send_email_notification
{
local ($to, $subject, $msg) = @_;
if ($module_info{'usermin'}) {
	&foreign_require("mailbox", "mailbox-lib.pl");
	local $from = &mailbox::get_preferred_from_address();
	&mailbox::send_text_mail($from, $to, undef, $subject, $msg);
	}
else {
	&foreign_require("mailboxes", "mailboxes-lib.pl");
	local $from = &mailboxes::get_from_address();
	&mailboxes::send_text_mail($from, $to, undef, $subject, $msg);
	}
}

# webmin_command_as_user(user, env, command)
# Return a command as some user with su if this is webmin, or un-changed for
# usermin
sub webmin_command_as_user
{
my ($user, $env, @args) = @_;
if ($module_info{'usermin'}) {
	return join(" ", @args);
	}
else {
	return &command_as_user($user, $env, @args);
	}
}

# expand_root_variables(dir, ...)
# Replaces $USER and $HOME in a list of dirs
sub expand_root_variables
{
local @rv;
local %hash = ( 'user' => $remote_user_info[0],
                'home' => $remote_user_info[7],
                'uid' => $remote_user_info[2],
                'gid' => $remote_user_info[3] );
my @ginfo = getgrgid($remote_user_info[3]);
$hash{'group'} = $ginfo[0];
foreach my $dir (@_) {
        push(@rv, &substitute_template($dir, \%hash));
        }
return @rv;
}

1;

