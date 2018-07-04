#!/usr/bin/perl
# chooser.cgi
# Outputs HTML for a frame-based file chooser

BEGIN { push(@INC, "."); };
use WebminCore;

@icon_map = (	"c", "text.gif",
		"txt", "text.gif",
		"pl", "text.gif",
		"cgi", "text.gif",
		"html", "text.gif",
		"htm", "text.gif",
		"php", "text.gif",
		"php5", "text.gif",
		"gif", "image.gif",
		"jpg", "image.gif",
		"jpeg", "image.gif",
		"png", "image.gif",
		"tar", "binary.gif"
		);

&init_config();
if (&get_product_name() eq 'usermin') {
	&switch_to_remote_user();
	}
%access = &get_module_acl();

# Work out root directory
local @uinfo = getpwnam($remote_user);
if (!$access{'root'}) {
	$rootdir = $uinfo[7] ? $uinfo[7] : "/";
	}
else {
	$rootdir = $access{'root'};
	$rootdir =~ s/^\~/$uinfo[7]/;
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
			&switch_to_unix_user(\@uinfo);
			}
		}
	}

&ReadParse(undef, undef, 1);

# If a chroot is forced which is under the allowed root, there is no need for
# a restrictred root
if ($in{'chroot'} && $in{'chroot'} ne '/' && $rootdir && $rootdir ne '/' &&
    $in{'chroot'} =~ /^\Q$rootdir\E/) {
	$rootdir = undef;
	}

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
$uchroot = &urlize($in{'chroot'});
$utype = &urlize($in{'type'});
$ufile = &urlize($in{'file'});

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
	     "src=\"$gconfig{'webprefix'}/chooser.cgi?frame=1&file=".$ufile.
	     "&chroot=".$uchroot."&type=".$utype."&add=$add\">\n";
	print "<frame marginwidth=0 marginheight=0 name=bottomframe ",
	      "src=\"$gconfig{'webprefix'}/chooser.cgi?frame=2&file=".$ufile.
	      "&chroot=".$uchroot."&type=".$utype."&add=$add\" scrolling=no>\n";
	print "</frameset>\n";
	}
elsif ($in{'frame'} == 1) {
	# List of files in this directory
	&popup_header();
	print <<EOF;
<script type='text/javascript'>
function fileclick(f, d)
{
curr = top.frames[1].document.forms[0].elements[1].value;
if (curr == f) {
	// Double-click! Enter directory or select file
	if (d) {
		// Enter this directory
		location = "chooser.cgi?frame=1&add=$add&chroot=$uchroot&type=$utype&file="+f+"/";
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
location = "chooser.cgi?frame=1&chroot=$uchroot&type=$utype&file="+p;
}
</script>
EOF
	print "<div id='filter_box' style='display:none;margin:0px;padding:0px;width:100%;clear:both;'>";
	print &ui_textbox("filter",$text{'ui_filterbox'}, 50, 0, undef,"style='width:100%;color:#aaa;' onkeyup=\"filter_match(this.value,'row',true);\" onfocus=\"if (this.value == '".$text{'ui_filterbox'}."') {this.value = '';this.style.color='#000';}\" onblur=\"if (this.value == '') {this.value = '".$text{'ui_filterbox'}."';this.style.color='#aaa';}\"");
	print &ui_hr("style='width:100%;'")."</div>";
	print "<b>",&text('chooser_dir', &html_escape($dir)),"</b>\n";
	$ok = opendir(DIR, $in{'chroot'}.$dir);
	&popup_error(&text('chooser_eopen', "$!")) if (!$ok && !$in{'chroot'});
	print &ui_columns_start(undef, 100);
    	my $cnt = 0;
	foreach $f (sort { $a cmp $b } readdir(DIR)) {
		$path = "$in{'chroot'}$dir$f";
		if ($f eq ".") { next; }
		if ($f eq ".." && ($dir eq "/" || $dir eq $topdir.'/')) { next; }
		if ($f =~ /^\./ && $f ne ".." && $access{'nodot'}) { next; }
		if (!(-d $path) && $in{'type'} == 1) { next; }

		@st = stat($path);
		$isdir = 0; undef($icon);
		if (-d $path) { $icon = "dir.gif"; $isdir = 1; }
		elsif ($path =~ /\.([^\.\/]+)$/) { $icon = $icon_map{$1}; }
		if (!$icon) { $icon = "unknown.gif"; }

		if ($f eq "..") {
			$dir =~ /^(.*\/)[^\/]+\/$/;
			$link = "<a href=\"\" onClick='parentdir(\"".&quote_javascript($1)."\"); return false'>";
			}
		else {
			$link = "<a href=\"\" onClick='fileclick(\"".&quote_javascript("$dir$f")."\", $isdir); return false'>";
			}
		local @cols;
		push(@cols, "$link<img border=0 src=$gconfig{'webprefix'}/images/$icon></a>");
		push(@cols, "$link".&html_escape($f)."</a>");
		push(@cols, &nice_size($st[7]));
		@tm = localtime($st[9]);
		push(@cols, sprintf "<tt>%.2d/%s/%.4d</tt>",
			$tm[3], $text{'smonth_'.($tm[4]+1)}, $tm[5]+1900);
		push(@cols, sprintf "<tt>%.2d:%.2d</tt>", $tm[2], $tm[1]);
		print &ui_columns_row(\@cols);
        	$cnt++;
		}
	closedir(DIR);
	print &ui_columns_end();
    if ( $cnt >= 10 ) {
        print "<script type='text/javascript' src='$gconfig{'webprefix'}/unauthenticated/filter_match.js?28112013'></script>";
        print "<script type='text/javascript'>filter_match_box();</script>";
    }
	&popup_footer();
	}
elsif ($in{'frame'} == 2) {
	# Current file and OK/cancel buttons
	&popup_header();
	print <<EOF;
<script type='text/javascript'>
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
	print &ui_form_start(undef, undef, undef,
		"onSubmit='filechosen(); return false'");
	print &ui_table_start(undef, "width=100%", 2);
	print &ui_table_row(&ui_submit($text{'chooser_ok'}),
		&ui_textbox("path", $dir.$file, 45, 0, undef,
			    "style='width:100%'"), 1,["width=5% valign=middle nowrap","valign=middle width=95%"]);
	print &ui_table_end();
	print &ui_form_end();
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
