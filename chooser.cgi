#!/usr/local/bin/perl
# chooser.cgi
# Outputs HTML for a frame-based file chooser 

@icon_map = (	"c", "text.gif",
		"txt", "text.gif",
		"pl", "text.gif",
		"cgi", "text.gif",
		"html", "text.gif",
		"htm", "text.gif",
		"gif", "image.gif",
		"jpg", "image.gif",
		"tar", "binary.gif"
		);

require (-r './web-lib.pl' ? './web-lib.pl' : '../web-lib.pl');
&init_config();
%access = &get_module_acl();

# Work out root directory
if (!$access{'root'}) {
	local @uinfo = getpwnam($remote_user);
	$rootdir = $uinfo[7] ? $uinfo[7] : "/";
	}
else {
	$rootdir = $access{'root'};
	}

# Switch to correct Unix user
if (&supports_users()) {
	if (&get_product_name() eq 'usermin') {
		# Always run as Usermin login
		&switch_to_remote_user();
		}
	else {
		# ACL determines
		$fileunix = $access{'fileunix'} || $remote_user;
		@uinfo = getpwnam($fileunix);
		if (@uinfo) {
			($(, $)) = ( $uinfo[3],
				     "$uinfo[3] ".join(" ", $uinfo[3],
						   &other_groups($uinfo[0])) );
			($>, $<) = ( $uinfo[2], $uinfo[2] );
			}
		}
	}

&ReadParse(undef, undef, 1);
if ($gconfig{'os_type'} eq 'windows') {
	# On Windows, chroot should be empty if not use, and default path
	# should be c:/
	if ($in{'chroot'} eq "/") {
		$in{'chroot'} = "";
		}
	if ($rootdir eq "/") {
		$rootdir = "c:";
		}
	}
if ($in{'add'}) {
	# Only use last filename by default
	$in{'file'} =~ s/\s+$//;
	if ($in{'file'} =~ /\n(.*)$/) {
		$in{'file'} = $1;
		}
	}
if ($in{'file'} =~ /^(([a-z]:)?.*\/)([^\/]*)$/i && $in{'file'} !~ /\.\./) {
	# File entered is valid
	$dir = $1;
	$file = $3;
	}
else {
	# Fall back to default
	$dir = $rootdir;
	$dir .= '/' if ($dir !~ /\/$/);
	$file = "";
	}
$add = int($in{'add'});

if (!(-d $in{'chroot'}.$dir)) {
	# Entered directory does not exist
	$dir = $rootdir.'/';
	$file = "";
	}
if (!&allowed_dir($dir)) {
	# Directory is outside allowed root
	$dir = $rootdir.'/';
	$file = "";
	}

# Work out the top allowed dir
$topdir = $rootdir eq "/" || $rootdir eq "c:" ? $rootdir :
	  $access{'otherdirs'} ? "/" : $rootdir;

if ($in{'frame'} == 0) {
	# base frame
	&PrintHeader();
	if ($in{'type'} == 0) {
		print "<title>$text{'chooser_title1'}</title>\n";
		}
	elsif ($in{'type'} == 1) {
		print "<title>$text{'chooser_title2'}</title>\n";
		}
	print "<frameset rows='*,50'>\n";
	print "<frame marginwidth=5 marginheight=5 name=topframe ",
	     "src=\"chooser.cgi?frame=1&file=".&urlize($in{'file'}).
	     "&chroot=".&urlize($in{'chroot'}).
	     "&type=".&urlize($in{'type'})."&add=$add\">\n";
	print "<frame marginwidth=0 marginheight=0 name=bottomframe ",
	      "src=\"chooser.cgi?frame=2&file=".&urlize($in{'file'}).
	      "&chroot=".&urlize($in{'chroot'}).
	      "&type=".&urlize($in{'type'})."&add=$add\" scrolling=no>\n";
	print "</frameset>\n";
	}
elsif ($in{'frame'} == 1) {
	# List of files in this directory
	&popup_header();
	print <<EOF;
<script>
function fileclick(f, d)
{
curr = top.frames[1].document.forms[0].elements[1].value;
if (curr == f) {
	// Double-click! Enter directory or select file
	if (d) {
		// Enter this directory
		location = "chooser.cgi?frame=1&add=$add&chroot=$in{'chroot'}&type=$in{'type'}&file="+f+"/";
		}
	else {
		// Select this file and close the window
		if ($add == 0) {
			top.opener.ifield.value = f;
			}
		else {
			if (top.opener.ifield.value != "") {
				top.opener.ifield.value += "\\n";
				}
			top.opener.ifield.value += f;
			}
		top.close();
		}
	}
else {
	top.frames[1].document.forms[0].elements[1].value = f;
	}
}

function parentdir(p)
{
top.frames[1].document.forms[0].elements[1].value = p;
location = "chooser.cgi?frame=1&chroot=$in{'chroot'}&type=$in{'type'}&file="+p;
}
</script>
EOF

	print "<b>",&text('chooser_dir', &html_escape($dir)),"</b>\n";
	opendir(DIR, $in{'chroot'}.$dir) ||
		&popup_error(&text('chooser_eopen', "$!"));
	print "<table width=100%>\n";
	foreach $f (sort { $a cmp $b } readdir(DIR)) {
		$path = "$in{'chroot'}$dir$f";
		if ($f eq ".") { next; }
		if ($f eq ".." && ($dir eq "/" || $dir eq $topdir.'/')) { next; }
		if ($f =~ /^\./ && $f ne ".." && $access{'nodot'}) { next; }
		if (!(-d $path) && $in{'type'} == 1) { next; }

		@st = stat($path);
		print "<tr>\n";
		$isdir = 0; undef($icon);
		if (-d $path) { $icon = "dir.gif"; $isdir = 1; }
		elsif ($path =~ /\.([^\.\/]+)$/) { $icon = $icon_map{$1}; }
		if (!$icon) { $icon = "unknown.gif"; }

		if ($f eq "..") {
			$dir =~ /^(.*\/)[^\/]+\/$/;
			$link = "<a href=\"\" onClick='parentdir(\"".&html_escape(quotemeta($1))."\"); return false'>";
			}
		else {
			$link = "<a href=\"\" onClick='fileclick(\"".&html_escape(quotemeta("$dir$f"))."\", $isdir); return false'>";
			}
		print "<td>$link<img border=0 src=/images/$icon></a></td>\n";
		print "<td nowrap>$link".&html_escape($f)."</a></td>\n";
		printf "<td nowrap>%s</td>\n",
			$st[7] > 1000000 ? int($st[7]/1000000)." MB" :
			$st[7] > 1000 ? int($st[7]/1000)." kB" :
			$st[7];
		@tm = localtime($st[9]);
		printf "<td nowrap><tt>%.2d/%s/%.4d</tt></td>\n",
			$tm[3], $text{'smonth_'.($tm[4]+1)}, $tm[5]+1900;
		printf "<td nowrap><tt>%.2d:%.2d</tt></td>\n", $tm[2], $tm[1];
		print "</tr>\n";
		}
	closedir(DIR);
	print "</table>\n";
	&popup_footer();
	}
elsif ($in{'frame'} == 2) {
	# Current file and OK/cancel buttons
	&popup_header();
	print <<EOF;
<script>
function filechosen()
{
if ($add == 0) {
	top.opener.ifield.value = document.forms[0].path.value;
	}
else {
	if (top.opener.ifield.value != "") {
		top.opener.ifield.value += "\\n";
		}
	top.opener.ifield.value += document.forms[0].path.value;
	}
top.close();
}
</script>
EOF
	print "<table>\n";
	print "<form onSubmit='filechosen(); return false'>\n";
	print "<tr><td><input type=submit value=\"$text{'chooser_ok'}\"></td>\n";
	print "<td><input name=path size=45 value=\"$dir$file\"></td></tr>\n";
	print "</form>\n";
	print "</table>\n";
	&popup_footer();
	}

# allowed_dir(dir)
# Returns 1 if some directory should be listable
sub allowed_dir
{
local ($dir) = @_;
return 1 if ($rootdir eq "" || $rootdir eq "/" || $rootdir eq "c:");
foreach my $allowed ($rootdir, split(/\t+/, $access{'otherdirs'})) {
	return 1 if (&is_under_directory($allowed, $dir));
	}
return 0;
}
