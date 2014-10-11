# file-lib.pl
# Common functions for file manager CGIs

BEGIN { push(@INC, ".."); };
use WebminCore;
&ReadParse(\%prein, 'GET');
if ($prein{'trust'}) {
	&open_trust_db();
	if ($trustdb{$prein{'trust'}}) {
		$trust_unknown_referers = 1;
		$trustdb{$prein{'trust'}} = time();
		}
	dbmclose(%trustdb);
	}
&init_config();

@file_buttons = ( "save", "preview", "edit", "info", "acl", "attr", "ext",
		  "search", "delete", "new", "upload", "mkdir", "makelink",
		  "rename", "sharing", "mount", "copy" );

if ($module_info{'usermin'}) {
	# Usermin gets the allowed list from the module config
	&switch_to_remote_user();
	&create_user_config_dirs();
	$hide_dot_files = $userconfig{'hide_dot_files'};
	$follow = int($config{'follow'});
	$real_home_dir = &simplify_path(&resolve_links($remote_user_info[7]));
	$upload_max = $config{'max'};

	if ($config{'home_only'} == 1) {
		@allowed_roots = ( $real_home_dir,
				   split(/\s+/, $config{'root'}) );
		}
	elsif ($config{'home_only'} == 2) {
		@allowed_roots = split(/\s+/, $config{'root'});
		}
	else {
		@allowed_roots = ( "/" );
		}
	@denied_roots = split(/\s+/, $config{'noroot'});
	@allowed_roots = &expand_root_variables(@allowed_roots);
	@denied_roots = &expand_root_variables(@denied_roots);

	if ($config{'archive'} eq 'y') {
		$archive = 1;
		}
	elsif ($config{'archive'} eq 'n') {
		$archive = 0;
		}
	else {
		$archive = 2;
		$archmax = $config{'archive'};
		}
	$unarchive = 1;
	$dostounix = 1;
	$chroot = "/";

	@disallowed_buttons = ( );
	foreach $k (keys %config) {
		if ($k =~ /^button_(.*)/ && $config{$k} == 0) {
			push(@disallowed_buttons, $1);
			}
		}
	$canperms = 1;
	$canusers = 1;
	$contents = 1;
	$running_as_root = 0;
	}
else {
	# Webmin gets the list of allowed directories from the ACL
	%access = &get_module_acl();
	$hide_dot_files = $config{'hide_dot_files'};
	$follow = int($access{'follow'});
	$upload_max = $access{'max'};

	@allowed_roots = split(/\s+/, $access{'root'});
	if ($access{'home'}) {
		local @u = getpwnam($remote_user);
		if (@u) {
			push(@allowed_roots,
			     &simplify_path(&resolve_links($u[7])));
			}
		}
	@denied_roots = split(/\s+/, $access{'noroot'});

	$archive = $access{'archive'};
	$archmax = $access{'archmax'};
	$unarchive = $access{'unarchive'};
	$dostounix = $access{'dostounix'};
	$chroot = $access{'chroot'};
	$access{'button_search'} = 0 if (!&has_command("find"));
	$access{'button_makelink'} = 0 if (!&supports_symlinks());
	$access{'button_info'} = 0 if (!&supports_users());

	@disallowed_buttons = grep { !$access{'button_'.$_} } @file_buttons;
	if (&is_readonly_mode()) {
		# Force read-only mode for file manager if global readonly
		# is in effect.
		$access{'ro'} = 1;
		}
	$canperms = $access{'noperms'} ? 0 : 1;
	$canusers = $access{'nousers'} ? 0 : 1;
	$contents = $access{'contents'};
	$running_as_root = !$access{'uid'};
	}
%disallowed_buttons = map { $_, 1 } @disallowed_buttons;

$icon_map = (	"c", 1,    "txt", 1,
		"pl", 1,   "cgi", 1,
		"html", 1, "htm", 1,
		"gif", 2,  "jpg", 2,
		"tar", 3,  "png", 2,
		);

# file_info_line(path, [displaypath])
# Returns a line of text containing encoded details of some file
sub file_info_line
{
local @st;
local $islink = (-l $_[0]);
local $f = $islink && &must_follow($_[0]);
local @st = $f ? stat($_[0]) : lstat($_[0]);
local $ext = $_[0] =~ /\S+\.([^\.\/]+)$/ ? $1 : undef;
local $dp = $_[1] || $_[0];
$dp =~ s/\\/\\\\/g;
$dp =~ s/\t/\\t/g;
return undef if ($dp =~ /\r|\n/);
return undef if (!@st);
local $type = $islink && !$f ? 5 :
	      -d _ ? 0 :
	      -b _ ? 6 :
	      -c _ ? 6 :
	      -p _ ? 7 :
	      -S _ ? 7 : defined($icon_map{$ext}) ? $icon_map{$ext} : 4;
local $user = !&supports_users() ? "root" :
	      %uid_to_user ? $uid_to_user{$st[4]} : getpwuid($st[4]);
$user = $st[4] if (!$user);
local $group = !&supports_users() ? "root" :
	       %gid_to_group ? $gid_to_group{$st[5]} :getgrgid($st[5]);
$group = $st[5] if (!$group);
local $rl = readlink($_[0]);
return join("\t", $dp, $type,
		  $user, $group,
		  $st[7] < 0 ? 2**32+$st[7] : $st[7], $st[2],
		  $st[9], $f ? "" : $islink && !$rl ? "???" : $rl);
}

# switch_acl_uid([user])
sub switch_acl_uid
{
local ($user) = @_;
return if ($module_info{'usermin'});	# Always already switched
local @u = $user ? getpwnam($user) :
	   $access{'uid'} < 0 ? getpwnam($remote_user) :
				getpwuid($access{'uid'});
if ($u[2]) {
	@u || &error($text{'switch_euser'});
	&switch_to_unix_user(\@u);
	umask(oct($access{'umask'}));
	}
}

# switch_acl_uid_and_chroot()
# Combines the switch_acl_uid and go_chroot functions
sub switch_acl_uid_and_chroot
{
if (!$module_info{'usermin'} && $access{'uid'}) {
	local @u = $access{'uid'} < 0 ? getpwnam($remote_user)
				      : getpwuid($access{'uid'});
	@u || &error($text{'switch_euser'});
	local @other = &other_groups($u[0]);
	&go_chroot();
	&switch_to_unix_user(\@u);
	umask(oct($access{'umask'}));
	}
else {
	&go_chroot();
	}
}

# can_access(file)
# Returns 1 if some file can be edited/deleted
sub can_access
{
local ($file) = @_;
$file =~ /^\// || return 0;
local $path = &simplify_path($file);
return &under_root_dir($path, \@allowed_roots) &&
       ($path eq "/" || !&under_root_dir($path, \@denied_roots));
}

# under_root_dir(file, &roots)
# Returns 1 if some file is under one of the given roots
sub under_root_dir
{
local $path = &simplify_path($_[0]);
local $roots = $_[1];
local @f = grep { $_ ne '' } split(/\//, $path);
local $r;
DIR: foreach $r (@$roots) {
	return 1 if ($r eq '/' || $path eq '/' || $path eq $r);
	local @a = grep { $_ ne '' } split(/\//, $r);
	local $i;
	for($i=0; $i<@a; $i++) {
		next DIR if ($a[$i] ne $f[$i]);
		}
	return 1;
	}
return 0;
}

# can_list(dir)
# Returns 1 if some directory can be listed. Parent directories of allowed
# directories are included as well.
sub can_list
{
local $path = &simplify_path($_[0]);
return &under_root_dir_or_parent($path, \@allowed_roots) &&
       ($path eq "/" || !&under_root_dir($path, \@denied_roots));
}

# under_root_dir_or_parent(file, &roots)
# Returns 1 if some file is under one of the given roots, or their parents
sub under_root_dir_or_parent
{
local @f = grep { $_ ne '' } split(/\//, $_[0]);
DIR: foreach $r (@allowed_roots) {
	return 1 if ($r eq '/' || $_[0] eq '/' || $_[0] eq $r);
	local @a = grep { $_ ne '' } split(/\//, $r);
	local $i;
	for($i=0; $i<@a && $i<@f; $i++) {
		next DIR if ($a[$i] ne $f[$i]);
		}
	return 1;
	}
return 0;
}

# accessible_subdir(dir)
# Returns the path to a dir under the given one that we can access
sub accessible_subdir
{
local ($r, @rv);
foreach $r (@allowed_roots) {
	if ($r =~ /^(\Q$_[0]\E\/[^\/]+)/) {
		push(@rv, $1);
		}
	}
return @rv;
}

sub open_trust_db
{
local $trust = $ENV{'WEBMIN_CONFIG'} =~ /\/usermin/ ?
	"/tmp/trust.$ENV{'REMOTE_USER'}" :
	"$ENV{'WEBMIN_CONFIG'}/file/trust";
eval "use SDBM_File";
dbmopen(%trustdb, $trust, 0700);
eval { $trustdb{'1111111111'} = 'foo bar' };
if ($@) {
	dbmclose(%trustdb);
	eval "use NDBM_File";
	dbmopen(%trustdb, $trust, 0700);
	}
}

# must_follow(path)
# For symlinks, returns 1 if a link should be follow, 0 if not
sub must_follow
{
if ($follow == 1) {
	return 1;
	}
elsif ($follow == 0) {
	return 0;
	}
else {
	local @s = stat($_[0]);
	local @l = lstat($_[0]);
	@st = ($s[4] == $l[4] ? @s : @l);
	return $s[4] == $l[4];
	}
}

# extract_archive(path, delete-after, get-contents)
# Called by upload to extract some zip or tar.gz file. Returns undef if
# something was actually done, an error message otherwise.
sub extract_archive
{
local ($path, $delete, $contents) = @_;
local $out;
$path =~ /^(\S*\/)/ || return 0;
local $dir = $1;
local $qdir = quotemeta($dir);
local $qpath = quotemeta($path);
if ($path =~ /\.zip$/i) {
	# Extract zip file
	return &text('zip_ecmd', "unzip") if (!&has_command("unzip"));
	if ($contents) {
		$out = `(cd $qdir; unzip -l $qpath) 2>&1 </dev/null`;
		}
	else {
		$out = `(cd $qdir; unzip -o $qpath) 2>&1 </dev/null`;
		}
	if ($?) {
		return &text('zip_eunzip', $out);
		}
	}
elsif ($path =~ /\.tar$/i) {
	# Extract un-compressed tar file
	return &text('zip_ecmd', "tar") if (!&has_command("tar"));
	if ($contents) {
		$out = `(cd $qdir; tar tf $qpath) 2>&1 </dev/null`;
		}
	else {
		$out = `(cd $qdir; tar xf $qpath) 2>&1 </dev/null`;
		}
	if ($?) {
		return &text('zip_euntar', $out);
		}
	}
elsif ($path =~ /\.(tar\.gz|tgz|tar\.bz|tbz|tar\.bz2|tbz2)$/i) {
	# Extract gzip or bzip2-compressed tar file
	local $zipper = $_[0] =~ /bz(2?)$/i ? "bunzip2"
					    : "gunzip";
	return &text('zip_ecmd', "tar") if (!&has_command("tar"));
	return &text('zip_ecmd', $zipper) if (!&has_command($zipper));
	if ($contents) {
		$out = `(cd $qdir; $zipper -c $qpath | tar tf -) 2>&1`;
		}
	else {
		$out = `(cd $qdir; $zipper -c $qpath | tar xf -) 2>&1`;
		}
	if ($?) {
		return &text('zip_euntar2', $out);
		}
	}
elsif ($path =~ /\.gz$/i) {
	# Uncompress gzipped file
	return &text('zip_ecmd', "gunzip") if (!&has_command("gunzip"));
	local $final = $_[0];
	$final =~ s/\.gz$//;
	local $qfinal = quotemeta($final);
	if ($contents) {
		$out = $final;
		$out =~ s/^.*\///;
		}
	else {
		$out = `(cd $qdir; gunzip -c $qpath >$qfinal) 2>&1`;
		}
	if ($?) {
		return &text('zip_euntar2', $out);
		}
	}
else {
	return $text{'zip_ename'};
	}
if ($contents) {
	return (undef, split(/\r?\n/, $out));
	}
elsif ($delete) {
	unlink($path);
	}
return undef;
}

# post_upload(path, dir, unzip)
sub post_upload
{
local ($path, $dir, $zip) = @_;
if ($unarchive == 2) {
	$zip = $path =~ /\.(zip|tgz|tar|tar\.gz)$/i ? 1 : 0;
	}
elsif ($unarchive == 0) {
	$zip = 0;
	}
local $refresh = $path;
local $err;
if ($zip) {
	$err = &extract_archive(&unmake_chroot($path), $zip-1);
	if (!$err) {
		# Refresh whole dir
		$refresh = $dir;
		}
	}
$info = &file_info_line(&unmake_chroot($refresh), $refresh);
print "<script>\n";
print "try {\n";
print "  opener.document.FileManager.",
      "upload_notify(\"".&quote_escape($refresh)."\", ",
      "\"".&quote_escape($info)."\");\n";
print "} catch(err) { }\n";
if ($err) {
	$err =~ s/\r//g;
	$err =~ s/\n/\\n/g;
	print "opener.document.FileManager.",
	      "upload_error(\"",&quote_escape(&text('zip_err', $err)),"\");\n";
	}
print "close();\n";
print "</script>\n";
}

sub go_chroot
{
if ($chroot ne "/" && $chroot ne "") {
	# First build hash of users and groups, which will not be accessible
	# after a chroot
	local (@u, @g);
	setpwent();
	while(@u = getpwent()) {
		$uid_to_user{$u[2]} = $u[0] if (!defined($uid_to_user{$u[2]}));
		$user_to_uid{$u[0]} = $u[2] if (!defined($user_to_uid{$u[0]}));
		}
	endpwent();
	setgrent();
	while(@g = getgrent()) {
		$gid_to_group{$g[2]} = $g[0] if(!defined($gid_to_group{$g[2]}));
		$group_to_gid{$g[0]} = $g[2] if(!defined($group_to_gid{$g[0]}));
		}
	endgrent();
	chroot($chroot) || die("chroot to $chroot failed");
	}
}

# make_chroot(dir)
# Converts some real directory to the chroot form
sub make_chroot
{
if ($chroot eq "/") {
	return $_[0];
	}
elsif ($_[0] eq $chroot) {
	return "/";
	}
else {
	local $rv = $_[0];
	if ($rv =~ /^$chroot\//) {
		$rv =~ s/^$chroot//;
		return $rv;
		}
	else {
		return undef;
		}
	}
}

# unmake_chroot(dir)
# Converts some chroot'd directory to the real form
sub unmake_chroot
{
if ($chroot eq "/") {
	return $_[0];
	}
elsif ($_[0] eq "/") {
	return $chroot;
	}
else {
	return $chroot.$_[0];
	}
}

# print_content_type([type])
# Prints the content-type header, with a charset
sub print_content_type
{
local $type = $_[0] || "text/plain";
if ($userconfig{'nocharset'} || $config{'nocharset'}) {
	# Never try to use charset
	print "Content-type: $type\n\n";
	}
else {
	my $charset = &get_charset();
	print "Content-type: $type; charset=$charset\n\n";
	}
}

# html_extract_head_body(html)
# Given some HTML, extracts the header, body and stuff after the body
sub html_extract_head_body
{
local ($html) = @_;
if ($html =~ /^([\000-\377]*<body[^>]*>)([\000-\377]*)(<\/body[^>]*>[\000-\377]*)/i) {
	return ($1, $2, $3);
	}
else {
	return (undef, $html, undef);
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

