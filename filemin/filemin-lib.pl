# filemin-lib.pl

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

use POSIX;
use Encode qw(decode encode);
use File::Basename;
eval "use File::MimeInfo";

our ($path, $quote_escaped_path, $urlized_path, $base, $cwd, $upload_max,
	 $confdir, $template_name, $bookmarks, $page, $pagelimit, $edit_icon,
	 $rename_icon, $extract_icon, $goto_icon, $root_icon, $head);
our (%access, %userconfig, %allowed_for_edit);
our (@allowed_paths, @allowed_for_edit, @remote_user_info);

# get_acls_status()
# Returns the getfacl command path if available
sub get_acls_status
{
return has_command('getfacl');
}

# get_list_acls_command()
# Returns the getfacl command with flags for listing ACLs
sub get_list_acls_command
{
return has_command('getfacl') . " -p ";
}

# get_attr_status()
# Returns the lsattr command path if available
sub get_attr_status
{
return has_command('lsattr');
}

# get_attr_command()
# Returns the lsattr command string for getting attributes
sub get_attr_command
{
return 'lsattr -d ';
}

# get_selinux_status()
# Returns whether SELinux is enabled
sub get_selinux_status
{
return is_selinux_enabled();
}

# get_selinux_command_type()
# Returns 1 if ls supports --scontext, 0 otherwise
sub get_selinux_command_type
{
my $out = backquote_command("ls --help 2>&1 </dev/null");
return $out =~ /--scontext/ ? 1 : 0;
}

# get_selinux_command()
# Returns the appropriate ls command for SELinux context
sub get_selinux_command
{
return get_selinux_command_type() ?
	'ls -d --scontext ' : 'ls -dmZ ';
}

# can_write(file)
# Checks if the current user can write to a file
sub can_write
{
my ($file) = @_;
# No restrictions for root
if (&webmin_user_is_admin()) {
	return 1;
	}
# If strict check is enabled or if safe user check for write
# access explicitly
if ($access{'work_as_user_strict'} || $access{'_safe'}) {
	# Check if the file is a symbolic link
	if (-l $file) {
		# Resolve symbolic link
		my $resolved_file = readlink($file);
		# If the link is broken, allow writing
		# to the link itself
		return -w $file if (!$resolved_file);
		# Otherwise, check the resolved file
		$file = $resolved_file;
		}
	# Check if the file itself is writable
	return -w $file;
	}
# Otherwise, allow writing depending on Unix permissions
else {
	return 1;
	}
}

# can_move(file, sdir, tdir)
# Checks if a file can be moved from source to target directory
sub can_move
{
my ($file, $sdir, $tdir) = @_;
# Check if the file itself is writable
return 0 if (!&can_write($file));
# Check if the source directory is writable
return 0 if (!-w $sdir);
# Check if the target directory is writable (if given)
return 1 if (!$tdir);
return -w $tdir;
}

# get_paths()
# Sets up access control, allowed paths, and per-user configuration
sub get_paths
{
%access = &get_module_acl();

# Get path from URL params
if ($in{'path'} =~ /^%2F/) {
	$path = un_urlize($in{'path'}, 1) || '';
	}
else {
	$path = $in{'path'} || '';
	}
$quote_escaped_path = quote_escape($path);
$urlized_path = urlize($path);

# Switch to the correct user
if (&get_product_name() eq 'usermin') {
	# In Usermin, the module only ever runs as the connected user
	&switch_to_remote_user();
	&create_user_config_dirs();
	}
elsif ($access{'work_as_root'}) {
	# Root user, so no switching
	@remote_user_info = getpwnam('root');
	@WebminCore::remote_user_info = @remote_user_info;
	}
elsif ($access{'work_as_dir'}) {
	# User is based on the directory
	my $switchto;
	foreach my $du (split(/\s+/, $access{'work_as_dir'})) {
		my ($user, $dir) = split(/:/, $du, 2);
		if (&is_under_directory($dir, $path)) {
			$switchto = $user;
			last;
			}
		}
	$switchto ||= $access{'work_as_user'};
	@remote_user_info = getpwnam($switchto);
	@remote_user_info ||
		&error("Unix user $switchto does not exist!");
	&switch_to_unix_user(\@remote_user_info);
	@WebminCore::remote_user_info = @remote_user_info;
	}
elsif ($access{'work_as_user'}) {
	# A specific user
	@remote_user_info = getpwnam($access{'work_as_user'});
	@remote_user_info ||
		&error("Unix user $access{'work_as_user'} " .
		       "does not exist!");
	&switch_to_unix_user(\@remote_user_info);
	@WebminCore::remote_user_info = @remote_user_info;
	}
else {
	# Run as the Webmin user we are connected as
	&switch_to_remote_user();
	}

# Get and check allowed paths
@allowed_paths = &get_allowed_paths($path);

# Work out max upload size
if (&get_product_name() eq 'usermin') {
	$upload_max = $config{'max'};
	}
else {
	$upload_max = $access{'max'};
	}

# Check that current directory is one of those that is allowed
$cwd = &simplify_path($base.$path);
my $error = 1;
for $allowed_path (@allowed_paths) {
	if (&is_under_directory($allowed_path, $cwd) ||
		$allowed_path =~ /^\Q$cwd\E/) {
		$error = 0;
		}
	}
if ($error) {
	&error(
		&text('notallowed',
		      '`' . &html_escape($cwd) . '`',
		      '`' . &html_escape(
			join(" , ", @allowed_paths)) .
		      '`.'));
	}

if (index($cwd, $base) == -1) {
	$cwd = $base;
	}

# Initiate per user config
$confdir = "$remote_user_info[7]/.filemin";
if (!-e $confdir) {
	mkdir $confdir or
		&error("$text{'error_creating_conf'}: $!");
	}
if (!-e "$confdir/.config") {
	&read_file_cached(
		"$module_root_directory/defaultuconf",
		\%userconfig);
	}
else {
	&read_file_cached("$confdir/.config", \%userconfig);
	}
&load_module_preferences(&get_module_name(), \%userconfig);
}

# get_allowed_paths(path)
# Returns list of simplified allowed paths for the current user
sub get_allowed_paths
{
my ($path) = @_;
if (!defined($access{'allowed_paths'})) {
	%access = &get_module_acl();
	}

my @paths = split(/\s+/, $access{'allowed_paths'});
my @rui;
if (&get_product_name() eq 'usermin') {
	@rui = $remote_user ? getpwnam($remote_user)
			    : getpwuid($<);
	}
elsif ($access{'work_as_root'}) {
	@rui = getpwnam('root');
	}
elsif ($access{'work_as_dir'}) {
	my $switchto;
	foreach my $du (split(/\s+/, $access{'work_as_dir'})) {
		my ($user, $dir) = split(/:/, $du, 2);
		if (&is_under_directory($dir, $path)) {
			$switchto = $user;
			last;
			}
		}
	$switchto ||= $access{'work_as_user'};
	@rui = getpwnam($switchto);
	@rui || &error("Unix user $switchto does not exist!");
	}
elsif ($access{'work_as_user'}) {
	@rui = getpwnam($access{'work_as_user'});
	@rui ||
		&error("Unix user $access{'work_as_user'} " .
		       "does not exist!");
	}
else {
	@rui = $remote_user ? getpwnam($remote_user)
			    : getpwuid($<);
	}
if (&get_product_name() eq 'usermin') {
	# Add paths from Usermin config
	push(@paths, split(/\t+/, $config{'allowed_paths'}));
	}
if ($rui[0] eq 'root' && @paths == 1 &&
    ($paths[0] eq '$HOME' || $paths[0] eq '$ROOT')) {
	# If the user is running as root and
	# the only allowed path is $HOME
	# or $ROOT, assume that all files are allowed
	$base = "/";
	@paths = ( $base );
	}
else {
	# Resolve actual allowed paths
	@paths = map { $_ eq '$HOME'
		? $rui[7]
		: $_ eq '$ROOT'
			? '/'
			: $_ } @paths;
	@paths = map { s/\$USER/$remote_user/g; $_ } @paths;
	@paths = &unique(@paths);
	@paths = map { my $p = $_; $p =~ s/\/\.\//\//; $p } @paths;
	if (scalar(@paths) == 1) {
		$base = $paths[0];
		}
	else {
		$base = '/';
		}
	}
return map { &simplify_path($_) } &unique(@paths);
}

# print_template(template_name)
# Loads and prints a template file with variable interpolation
sub print_template
{
$template_name = @_[0];
if (open(my $fh, '<:encoding(UTF-8)', $template_name)) {
	while (my $row = <$fh>) {
		print (eval "qq($row)");
		}
	}
else {
	print "$text{'error_load_template'} '$template_name' $!";
	}
}

# print_errors(&errors)
# Displays a list of errors to the user
sub print_errors
{
my (@errors) = @_;
&ui_print_header(undef, $module_info{'name'}, "");
print "<tt>$text{'errors_occured'}</tt><br>";
print "<ul class=\"err-body\">";
foreach $error (@errors) {
	print("<li><tt>$error</tt></li>");
	}
print "</ul>";
print "<script>",
      "if(typeof print_errors_post==='function')",
      "{print_errors_post('$module_name')}",
      "</script>";
&ui_print_footer(
	"index.cgi?path=".&urlize($path),
	$text{'previous_page'});
}

# print_interface()
# Renders the file manager interface including breadcrumbs and file listing
sub print_interface
{
# Some vars for "upload" functionality
local $upid = time().$$;
$bookmarks = get_bookmarks();
@allowed_for_edit = split(/\s+/, $access{'allowed_for_edit'});
# Some experimental MIME types are now recognized
push(@allowed_for_edit, map { (my $__ = $_) =~ s/-x-/-/;
	$__ ne $_ ? $__ : () } @allowed_for_edit);
%allowed_for_edit = map { $_ => 1} @allowed_for_edit;
my %tinfo = &get_theme_info($current_theme);

# User and group lists for acls
if (&has_command('setfacl')) {
	our $acl_user_select =
		&ui_user_textbox("user", $realuser);
	our $acl_group_select =
		&ui_user_textbox("group", $realuser);
	our $acl_manual = &ui_details(
		{ title => $text{'acls_manual'},
		  content => &ui_textbox(
			"manual", undef, 40, undef, undef,
			"placeholder='-m u:root:rw-," .
			"g:stream:r-x -R'"),
		  html => 1 } );
	}

# Interface for Bootstrap powered themes
if ($tinfo{'bootstrap'}) {

	# Set icons variables
	$edit_icon =
		"<i class='fa fa-edit' " .
		"alt='$text{'edit'}'></i>";
	$rename_icon =
		"<i class='fa fa-font' " .
		"title='$text{'rename'}'></i>";
	$extract_icon =
		"<i class='fa fa-external-link' " .
		"alt='$text{'extract_archive'}'></i>";
	$goto_icon =
		"<i class='fa fa-arrow-right' " .
		"alt='$text{'goto_folder'}'></i>";

	# Add static files
	print "<link rel=\"stylesheet\" " .
	      "type=\"text/css\" " .
	      "href=\"unauthenticated/css/style.css\"" .
	      " />";
	print "<script type=\"text/javascript\" " .
	      "src=\"unauthenticated/js/main.js\">" .
	      "</script>";
	print "<script type=\"text/javascript\" " .
	      "src=\"unauthenticated/js/" .
	      "chmod-calculator.js\"></script>";
	print "<script type=\"text/javascript\" " .
	      "src=\"unauthenticated/js/" .
	      "bootstrap-hover-dropdown.min.js\">" .
	      "</script>";

	# Set "root" icon
	if ($base eq '/') {
		$root_icon =
			"<i class='fa fa-hdd-o'></i>";
		}
	else {
		$root_icon = "~";
		}

	# Breadcrumbs
	print "<ol class='breadcrumb pull-left'>" .
	      "<li><a href='index.cgi?path='>" .
	      "$root_icon</a></li>";
	my @breadcr = split('/', $path);
	my $cp = '';
	for (my $i = 1;
	     $i <= scalar(@breadcr)-1; $i++) {
		chomp($breadcr[$i]);
		$cp = $cp.'/'.$breadcr[$i];
		print "<li><a href='index.cgi?path=" .
		      &urlize($cp) . "'>" .
		      &html_escape($breadcr[$i]) .
		      "</a></li>";
		}
	print "</ol>";

	$page = 1;
	# The maximum number of files in an EXT4
	# directory. 9000+ is far too small here.
	$pagelimit = 4294967295;

	# And toolbar
	print_template(
		"unauthenticated/templates/menu.html");
	print_template(
		"unauthenticated/templates/dialogs.html");
	}

# Interface for legacy themes
else {

	# Set icons variables
	$edit_icon =
		"<img src='images/icons/quick/edit.png'" .
		" alt='$text{'edit'}' />";
	$rename_icon =
		"<img src='images/icons/quick/" .
		"rename.png' " .
		"alt='$text{'rename'}' />";
	$extract_icon =
		"<img src='images/icons/quick/" .
		"extract.png' " .
		"alt='$text{'extract_archive'}' />";
	$goto_icon =
		"<img src='images/icons/quick/" .
		"go-next.png' " .
		"alt='$text{'goto_folder'}'";

	# Add static files
	$head = "<link rel=\"stylesheet\" " .
		"type=\"text/css\" " .
		"href=\"unauthenticated/css/" .
		"style.css\" />";
	$head .= "<script type=\"text/javascript\"" .
		 " src=\"unauthenticated/jquery/" .
		 "jquery.min.js\"></script>";
	$head .= "<script type=\"text/javascript\"" .
		 " src=\"unauthenticated/jquery/" .
		 "jquery-ui.min.js\"></script>";
	$head .= "<script type=\"text/javascript\"" .
		 " src=\"unauthenticated/js/" .
		 "legacy.js\"></script>";
	$head .= "<link rel=\"stylesheet\" " .
		 "type=\"text/css\" " .
		 "href=\"unauthenticated/jquery/" .
		 "jquery-ui.min.css\" />";
	$head .= "<script type=\"text/javascript\"" .
		 " src=\"unauthenticated/js/" .
		 "chmod-calculator.js\"></script>";
	$head .= "<link rel=\"stylesheet\" " .
		 "type=\"text/css\" " .
		 "href=\"unauthenticated/dropdown/" .
		 "fg.menu.css\" />";
	$head .= "<script type=\"text/javascript\"" .
		 " src=\"unauthenticated/dropdown/" .
		 "fg.menu.js\"></script>";
	print $head;

	# Set "root" icon
	if ($base eq '/') {
		$root_icon =
			"<img src=\"images/icons/quick/" .
			"drive-harddisk.png\" " .
			"class=\"hdd-icon\" />";
		}
	else {
		$root_icon = "~";
		}
	# Legacy breadcrumbs
	print "<div id='bread' style='float: left;" .
	      " padding-bottom: 2px;'>" .
	      "<a href='index.cgi?path='>" .
	      "$root_icon</a> / ";
	my @breadcr = split('/', $path);
	my $cp = '';
	for (my $i = 1;
	     $i <= scalar(@breadcr)-1; $i++) {
		chomp($breadcr[$i]);
		$cp = $cp.'/'.$breadcr[$i];
		print "<a href='index.cgi?path=" .
		      &urlize($cp) . "'>" .
		      &html_escape($breadcr[$i]) .
		      "</a> / ";
		}
	print "<br />";
	# And pagination
	$page = $in{'page'};
	$pagelimit = $userconfig{'per_page'};
	$pages = ceil((scalar(@list))/$pagelimit);
	if (not defined $page or $page > $pages) {
		$page = 1;
		}
	print "Pages: ";
	for (my $i = 1; $i <= $pages; $i++) {
		if ($page eq $i) {
			print "<a class='pages active' " .
			      "href='?path=" .
			      &urlize($path) .
			      "&page=$i" .
			      "&query=" .
			      &urlize($query) .
			      "'>" .
			      &html_escape($i) .
			      "</a>";
			}
		else {
			print "<a class='pages' " .
			      "href='?path=" .
			      &urlize($path) .
			      "&page=$i" .
			      "&query=" .
			      &urlize($query) .
			      "'>" .
			      &html_escape($i) .
			      "</a>";
			}
		}
	print "</div>";

	# And toolbar
	print_template(
		"unauthenticated/templates/" .
		"legacy_quicks.html");
	print_template(
		"unauthenticated/templates/" .
		"legacy_dialogs.html");
	}
my $info_total;
my $info_files = scalar @files;
my $info_folders = scalar @folders;

if ($info_files eq 1 && $info_folders eq 1) {
	$info_total = 'info_total1'
	}
elsif ($info_files ne 1 && $info_folders eq 1) {
	$info_total = 'info_total2'
	}
elsif ($info_files eq 1 && $info_folders ne 1) {
	$info_total = 'info_total3'
	}
else {
	$info_total = 'info_total4'
	}

print "<div class='total'>" .
      &text($info_total,
	    scalar @files, scalar @folders) .
      "</div>";

# Render current directory entries
print &ui_form_start("", "post", undef,
	"id='list_form'");
@ui_columns = (
	'<input class="_select-unselect_" ' .
	'type="checkbox" ' .
	'onclick="selectUnselect(this)" />',
	''
	);
push @ui_columns,
	('<span data-head-name>' .
	 $text{'name'} . '</span>');
push @ui_columns,
	('<span data-head-type>' .
	 $text{'type'} . '</span>')
	if ($userconfig{'columns'} =~ /type/);
push @ui_columns,
	('<span data-head-actions>' .
	 $text{'actions'} . '</span>');
push @ui_columns,
	('<span data-head-size>' .
	 $text{'size'} . '</span>')
	if ($userconfig{'columns'} =~ /size/);
push @ui_columns,
	('<span data-head-owner_user>' .
	 $text{'ownership'} . '</span>')
	if ($userconfig{'columns'} =~ /owner_user/);
push @ui_columns,
	('<span data-head-permissions>' .
	 $text{'permissions'} . '</span>')
	if ($userconfig{'columns'} =~ /permissions/);
push @ui_columns,
	('<span data-head-acls>' .
	 $text{'acls'} . '</span>')
	if (get_acls_status() &&
	    $userconfig{'columns'} =~ /acls/);
push @ui_columns,
	('<span data-head-attributes>' .
	 $text{'attributes'} . '</span>')
	if (get_attr_status() &&
	    $userconfig{'columns'} =~ /attributes/);
push @ui_columns,
	('<span data-head-selinux>' .
	 $text{'selinux'} . '</span>')
	if (get_selinux_status() &&
	    $userconfig{'columns'} =~ /selinux/);
push @ui_columns,
	('<span data-head-last_mod_time>' .
	 $text{'last_mod_time'} . '</span>')
	if ($userconfig{'columns'} =~ /last_mod_time/);

print &ui_columns_start(\@ui_columns);
#foreach $link (@list) {
for (my $count = 1 + $pagelimit * ($page - 1);
     $count <= $pagelimit + $pagelimit * ($page - 1);
     $count++) {
	if ($count > scalar(@list)) { last; }
	my $class = $count & 1 ? "odd" : "even";
	my $link = $list[$count - 1][0];
	my $acls;
	my $attributes;
	my $selinux;
	$link =~ s/\Q$cwd\E\///;
	$link =~ s/^\///g;
	$vlink = html_escape($link);
	$vlink = quote_escape($vlink);
	my $hlink = html_escape($vlink);
	$vpath = quote_escape($vpath);

	my $type = $list[$count - 1][14];
	$type =~ s/\//\-/g;

	my $img =
		"images/icons/mime/$type.png";
	unless (-e $img) {
		$img = "images/icons/mime/unknown.png";
		}
	$size = &nice_size($list[$count - 1][8]);
	$user = getpwuid($list[$count - 1][5]) ?
		getpwuid($list[$count - 1][5]) :
		$list[$count - 1][5];
	$group = getgrgid($list[$count - 1][6]) ?
		getgrgid($list[$count - 1][6]) :
		$list[$count - 1][6];
	$permissions = sprintf("%04o",
		$list[$count - 1][3] & 07777);

	if (get_selinux_status() &&
	    $userconfig{'columns'} =~ /selinux/) {
		$selinux = $list[$count - 1][17];
		}

	if (get_attr_status() &&
	    $userconfig{'columns'} =~ /attributes/) {
		$attributes = $list[$count - 1][18];
		}

	if (get_acls_status() &&
	    $userconfig{'columns'} =~ /acls/) {
		$acls = $list[$count - 1][19];
		}

	$mod_time = POSIX::strftime(
		'%Y/%m/%d - %T',
		localtime($list[$count - 1][10]));

	$actions =
		"<a class='action-link' " .
		"href='javascript:void(0)' " .
		"onclick='renameDialog(\"$vlink\")' " .
		"title='$text{'rename'}' " .
		"data-container='body'>" .
		"$rename_icon</a>";

	if ($list[$count - 1][15] == 1) {
		$href = "index.cgi?path=" .
			&urlize("$path/$link");
		}
	else {
		$href = "download.cgi?file=" .
			&urlize($link) .
			"&path=" . &urlize($path);
		if ($0 =~ /search.cgi/) {
			($fname, $fpath, $fsuffix) =
				fileparse(
				$list[$count - 1][0]);
			if ($base ne '/') {
				$fpath =~
					s/^\Q$base\E//g;
				}
			$actions =
				"$actions" .
				"<a class='action-link' " .
				"href='index.cgi?path=" .
				&urlize($fpath) . "' " .
				"title='$text{'goto_folder'}'>" .
				"$goto_icon</a>";
			}
		if (
			index($type, "text-") != -1 or
			exists($allowed_for_edit{$type})
		) {
			$actions =
				"$actions" .
				"<a class='action-link' " .
				"href='edit_file.cgi?file=" .
				&urlize($link) .
				"&path=" .
				&urlize($path) . "' " .
				"title='$text{'edit'}' " .
				"data-container='body'>" .
				"$edit_icon</a>";
			}
		if ((index($type,
			   "application-zip") != -1 &&
		     has_command('unzip')) ||
		    ((index($type,
			"application-x-7z-" .
			"compressed") != -1 ||
		      index($type,
			"x-raw-disk-image") != -1 ||
		      index($type,
			"x-cd-image") != -1
		     ) && has_command('7z')) ||
		    ((index($type,
			"application-x-rar") != -1 ||
		      index($type,
			"application-vnd.rar") != -1
		     ) && has_command('unrar')) ||
		    (index($type,
			"application-x-rpm") != -1 &&
		     has_command('rpm2cpio') &&
		     has_command('cpio')) ||
		    (index($type,
			"application-x-deb") != -1 &&
		     has_command('dpkg')) ||
		    ((index($type,
			"x-compressed-tar") != -1 ||
		      index($type,
			"-x-tar") != -1 ||
		      (index($type,
			"-x-bzip") != -1 &&
		       has_command('bzip2')) ||
		      (index($type,
			"-gzip") != -1 &&
		       has_command('gzip')) ||
		      (index($type,
			"zstd") != -1 &&
		       has_command('zstd')) ||
		      (index($type,
			"-x-xz") != -1 &&
		       has_command('xz'))
		     ) && has_command('tar'))) {
			$actions =
				"$actions " .
				"<a class='action-link' " .
				"href='extract.cgi?path=" .
				&urlize($path) .
				"&file=" .
				&urlize($link) . "' " .
				"title='$text" .
				"{'extract_archive'}' " .
				"data-container='body'>" .
				"$extract_icon</a> ";
			}

		}
	@row_data = (
		"<a href='$href'>" .
		"<img src=\"$img\"></a>",
		"<a href=\"$href\" " .
		"data-filemin-path=\"$href\" " .
		"data-filemin-link=\"$hlink\">" .
		"$vlink</a>"
		);
	push @row_data, $type
		if ($userconfig{'columns'} =~ /type/);
	push @row_data, $actions;
	push @row_data, $size
		if ($userconfig{'columns'} =~ /size/);
	push @row_data, $user . ':' . $group
		if ($userconfig{'columns'} =~
		    /owner_user/);
	push @row_data, $permissions
		if ($userconfig{'columns'} =~
		    /permissions/);
	push @row_data, $acls
		if (get_acls_status() &&
		    $userconfig{'columns'} =~ /acls/);
	push @row_data, $attributes
		if (get_attr_status() &&
		    $userconfig{'columns'} =~
		    /attributes/);
	push @row_data, $selinux
		if (get_selinux_status() &&
		    $userconfig{'columns'} =~
		    /selinux/);
	push @row_data, $mod_time
		if ($userconfig{'columns'} =~
		    /last_mod_time/);

	print &ui_checked_columns_row(
		\@row_data, "", "name", $vlink);
	}
print ui_columns_end();
print &ui_hidden("path", $path),"\n";
print &ui_form_end();
}

# get_bookmarks()
# Returns HTML list items of saved bookmarks
sub get_bookmarks
{
$confdir = "$remote_user_info[7]/.filemin";
if (!-e "$confdir/.bookmarks") {
	return "<li><a>$text{'no_bookmarks'}</a></li>";
	}
my $bookmarks =
	&read_file_lines($confdir.'/.bookmarks', 1);
$result = '';
foreach $bookmark (@$bookmarks) {
	$result .=
		"<li><a href='index.cgi?path=" .
		&urlize($bookmark) . "'>" .
		&html_escape($bookmark) .
		"</a></li>";
	}
return $result;
}

# get_paste_buffer_file()
# Returns the location of the file for temporary copy/paste state
sub get_paste_buffer_file
{
if (&get_product_name() eq 'usermin') {
	return $user_module_config_directory."/.buffer";
	}
else {
	my $tmpdir = "$remote_user_info[7]/.filemin";
	&make_dir($tmpdir, 0700) if (!-d $tmpdir);
	return $tmpdir."/.buffer";
	}
}

# check_allowed_path(file)
# Calls error if some path isn't allowed
sub check_allowed_path
{
my ($file) = @_;
$file = &simplify_path($file);
my $error = 1;
foreach my $allowed_path (@allowed_paths) {
	if (&is_under_directory($allowed_path, $file)) {
		$error = 0;
		}
	}
$error && &error(
	&text('notallowed',
	      '`' . &html_escape($file) . '`',
	      '`' . &html_escape(
		join(" , ", @allowed_paths)) . '`.'));
}

# filemin_path_under_directory(directory, file)
# Like is_under_directory, but permits legitimate names containing "..".
sub filemin_path_under_directory
{
my ($dir, $file) = @_;
$dir = &simplify_path($dir);
$file = &simplify_path($file);
return 0 if (!defined($dir) || !defined($file));
return 1 if ($dir eq "/");
$dir = &simplify_path(&resolve_links($dir));
$file = &simplify_path(&resolve_links($file));
return 0 if (!defined($dir) || !defined($file));
return 1 if ($dir eq $file);
$dir =~ s/\/*$/\//;
return substr($file, 0, length($dir)) eq $dir;
}

# filemin_lexical_path_under_directory(directory, file)
# Like filemin_path_under_directory, but does not resolve symlinks. Used before
# the allowed-path check to make sure the submitted name was relative to the
# current directory, while still allowing symlinks to other allowed paths.
sub filemin_lexical_path_under_directory
{
my ($dir, $file) = @_;
$dir = &simplify_path($dir);
$file = &simplify_path($file);
return 0 if (!defined($dir) || !defined($file));
return 1 if ($dir eq "/");
return 1 if ($dir eq $file);
$dir =~ s/\/*$/\//;
return substr($file, 0, length($dir)) eq $dir;
}

# validate_filename_path(file)
# Returns a checked full path for a name or relative path from the current
# directory, or calls error if it could escape the allowed paths.
sub validate_filename_path
{
my ($file) = @_;
my $display_file = defined($file) ? $file : '';
if (!defined($file) || $file eq '' || $file =~ /[\0\r\n]/ ||
    $file =~ m!(^|/)\.\.(?:/|$)!) {
	&error(&text('error_invalid_filename',
		     '<tt>'.&html_escape($display_file).'</tt>'));
	}
my $full = &simplify_path("$cwd/$file");
if (!defined($full) || !&filemin_lexical_path_under_directory($cwd, $full)) {
	&error(&text('error_invalid_filename',
		     '<tt>'.&html_escape($display_file).'</tt>'));
	}
my $allowed = 0;
foreach my $allowed_path (@allowed_paths) {
	if (&filemin_path_under_directory($allowed_path, $full)) {
		$allowed = 1;
		last;
		}
	}
if (!$allowed) {
	&error(
		&text('notallowed',
		      '`' . &html_escape($full) . '`',
		      '`' . &html_escape(
			join(" , ", @allowed_paths)) . '`.'));
	}
return $full;
}

# clean_mimetype(file)
# Returns the MIME type for a file, ensuring proper encoding
sub clean_mimetype
{
my ($f) = @_;
my $t = mimetype($f);
eval { utf8::encode($t) if (utf8::is_utf8($t)) };
return $t;
}

# test_allowed_paths()
# Returns 1 if paths are restricted, 0 if all files are allowed
sub test_allowed_paths
{
if (@allowed_paths == 1 && $allowed_paths[0] eq '/') {
	return 0;
	}
return 1;
}

# extract_files(&files_to_extract, delete)
# Extracts archives and optionally deletes them after extraction
sub extract_files
{
my ($files_to_extract, $delete) = @_;
my @errors;
foreach my $fref (@{$files_to_extract}) {
	my $status = -1;

	my $extract_cwd = &simplify_path($fref->{'path'});
	my $name = $fref->{'file'};
	if (!defined($extract_cwd)) {
		&error(&text('error_invalid_filename',
			     '<tt>'.&html_escape($fref->{'path'}).'</tt>'));
		}
	&check_allowed_path($extract_cwd);
	my $archive;
	{
	local $cwd = $extract_cwd;
	$archive = &validate_filename_path($name);
	}

	my $extract_to = $extract_cwd;
	if (!$in{'overwrite_existing'}) {
		my ($file_name) = $name =~ /(?|
			(.*)\.((?|tar|wbm|wbt)\..*) |
			(.*)\.([a-zA-Z]+\.(?|gpg|pgp)) |
			(.*)\.(?=(.*)) |
			(.*)()
		)/x;
		my $candidate;
		{
		local $cwd = $extract_cwd;
		$candidate = &validate_filename_path($file_name);
		}
		if (!-e $candidate) {
			$extract_to = $candidate;
			}
		else {
			my $__ = 1;
			for (;;) {
				my $new_dir_name =
					"$file_name(" . $__++ . ")";
				{
				local $cwd = $extract_cwd;
				$candidate =
					&validate_filename_path(
						$new_dir_name);
				}
				if (!-e $candidate) {
					$extract_to = $candidate;
					last;
					}
				}
			}
		}
	mkdir($extract_to);

	my $archive_type =
		mimetype($archive);

	if ($archive_type =~ /x-tar/ ||
	    $archive_type =~ /-compressed-tar/) {
		my $tar_cmd = has_command('tar');
		if (!$tar_cmd) {
			push(@errors,
			     &text('extract_cmd_not_avail',
				   "<tt>" .
				   &html_escape($name) .
				   "</tt>",
				   '<tt>tar</tt>'));
			}
		else {
			$status = system(
				"$tar_cmd xpf " .
				quotemeta($archive) .
				" -C " .
				quotemeta($extract_to));
			}
		}
	elsif ($archive_type =~ /x-bzip/) {
		my $tar_cmd = has_command('tar');
		if (!$tar_cmd) {
			push(@errors,
			     &text('extract_cmd_not_avail',
				   "<tt>" .
				   &html_escape($name) .
				   "</tt>",
				   '<tt>tar</tt>'));
			}
		else {
			$status = system(
				"$tar_cmd xjfp " .
				quotemeta($archive) .
				" -C " .
				quotemeta($extract_to));
			}
		}
	elsif ($archive_type =~ /\/gzip/) {
		my $gz_cmd = has_command('gunzip') ||
			has_command('gzip');
		if (!$gz_cmd) {
			push(@errors,
			     &text('extract_cmd_not_avail',
				   "<tt>" .
				   &html_escape($name) .
				   "</tt>",
				   '<tt>gzip/gunzip</tt>'));
			}
		else {
			$status = system(
				"$gz_cmd -d -f -k " .
				quotemeta($archive));
			}
		}
	elsif ($archive_type =~ /x-xz/) {
		my $xz_cmd = has_command('xz');
		if (!$xz_cmd) {
			push(@errors,
			     &text('extract_cmd_not_avail',
				   "<tt>" .
				   &html_escape($name) .
				   "</tt>",
				   '<tt>xz</tt>'));
			}
		else {
			$status = system(
				"$xz_cmd -d -f -k " .
				quotemeta($archive));
			}
		}
	elsif ($archive_type =~ /x-7z/ ||
	       $archive_type =~ /x-raw-disk-image/ ||
	       $archive_type =~ /x-cd-image/) {
		my $x7z_cmd = has_command('7z');
		if (!$x7z_cmd) {
			push(@errors,
			     &text('extract_cmd_not_avail',
				   "<tt>" .
				   &html_escape($name) .
				   "</tt>",
				   '<tt>7z</tt>'));
			}
		else {
			$status = system(
				"$x7z_cmd x -aoa " .
				quotemeta($archive) .
				" -o" .
				quotemeta($extract_to));
			}
		}
	elsif ($archive_type =~ /\/zip/) {
		my $unzip_cmd = has_command('unzip');
		if (!$unzip_cmd) {
			push(@errors,
			     &text('extract_cmd_not_avail',
				   "<tt>" .
				   &html_escape($name) .
				   "</tt>",
				   '<tt>unzip</tt>'));
			}
		else {
			my $unzip_out = `unzip --help`;
			my $uu = ($unzip_out =~ /-UU/
				? '-UU' : undef);
			$status = system(
				"$unzip_cmd $uu -q -o " .
				quotemeta($archive) .
				" -d " .
				quotemeta($extract_to));
			}
		}
	elsif ($archive_type =~ /\/x-rar|\/vnd\.rar/) {
		my $unrar_cmd = has_command('unar') ||
			has_command('unrar');
		if (!$unrar_cmd) {
			push(@errors,
			     &text('extract_cmd_not_avail',
				   "<tt>" .
				   &html_escape($name) .
				   "</tt>",
				   '<tt>unrar/unar</tt>'));
			}
		else {
			if ($unrar_cmd =~ /unar$/) {
				$status = system(
					"$unrar_cmd " .
					quotemeta($archive) .
					" -o " .
					quotemeta(
					$extract_to));
				}
			else {
				$status = system(
					"$unrar_cmd " .
					"x -r -y -o+ " .
					quotemeta($archive) .
					" " .
					quotemeta(
					$extract_to));
				}
			}
		}
	elsif ($archive_type =~ /\/x-rpm/) {
		my $rpm2cpio_cmd =
			has_command('rpm2cpio');
		my $cpio_cmd = has_command('cpio');
		if (!$rpm2cpio_cmd) {
			push(@errors,
			     &text('extract_cmd_not_avail',
				   "<tt>" .
				   &html_escape($name) .
				   "</tt>",
				   '<tt>rpm2cpio</tt>'));
			}
		elsif (!$cpio_cmd) {
			push(@errors,
			     &text('extract_cmd_not_avail',
				   "<tt>" .
				   &html_escape($name) .
				   "</tt>",
				   '<tt>cpio</tt>'));
			}
		else {
			$status = system(
				"($rpm2cpio_cmd " .
				quotemeta($archive) .
				" | (cd " .
				quotemeta($extract_to) .
				"; $cpio_cmd -idmv))");
			}
		}
	elsif ($archive_type =~
	       /\/x-deb|debian\.binary-package/) {
		my $dpkg_cmd = has_command('dpkg');
		if (!$dpkg_cmd) {
			push(@errors,
			     &text('extract_cmd_not_avail',
				   "<tt>" .
				   &html_escape($name) .
				   "</tt>",
				   '<tt>dpkg</tt>'));
			}
		else {
			$status = system(
				"$dpkg_cmd -x " .
				quotemeta($archive) .
				" " .
				quotemeta($extract_to));
			}
		}

	# Set permissions for all extracted files
	my @perms = stat($archive);
	system("chown -R $perms[4]:$perms[5] " .
		quotemeta($extract_to));

	# Delete empty extraction
	rmdir($extract_to);

	# Delete if no error
	if ($delete && $status == 0) {
		unlink_file($archive);
		}
	}
return @errors;
}

1;
