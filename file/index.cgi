#!/usr/local/bin/perl
# index.cgi
# Output HTML for the file manager applet

require './file-lib.pl';
&ReadParse();
$theme_no_table = 1;
if ($access{'uid'} < 0 && !defined(getpwnam($remote_user))) {
	&error(&text('index_eremote', $remote_user));
	}

# Display header, depending on how many modules the user has
&read_acl(undef, \%acl);
$mc = @{$acl{$base_remote_user}} == 1;
$nolo = $ENV{'ANONYMOUS_USER'} ||
      $ENV{'SSL_USER'} || $ENV{'LOCAL_USER'} ||
      $ENV{'HTTP_USER_AGENT'} =~ /webmin/i;
if ($gconfig{'gotoone'} && $mc == 1 && !$nolo) {
	&header($text{'index_title'}, "", undef, 0, 1);
	$w = 100;
	$h = 80;
	}
else {
	&header($text{'index_title'});
	$w = 100;
	$h = 100;
	if (!$tconfig{'inframe'}) {
		$return = "<param name=return value=\"$gconfig{'webprefix'}/?cat=$module_info{'category'}\">";
		$returnhtml = &text('index_index',
				    "$gconfig{'webprefix'}/")."<p>";
		}
	}

if ($gconfig{'referers_none'}) {
	# Because java applet HTTP requests don't always include a referer:
	# header, we need to use a DBM of trust keys to identify trusted applets
	if (defined(&seed_random)) { &seed_random(); }
	else { srand(time() ^ $$); }
	$trust = int(rand(1000000000));
	local $now = time();
	&open_trust_db();
	foreach $k (keys %trustdb) {
		if ($now - $trustdb{$k} > 30*24*60*60) {
			delete($trustdb{$k});
			}
		}
	$trustdb{$trust} = $now;
	dbmclose(%trustdb);
	}

$sharing = $access{'uid'} ? 0 : 1;
$mounting = !$access{'uid'} && &foreign_check("mount") ? 1 : 0;
if ($in{'open'}) {
	$open = "<param name=open value=\"".&html_escape($in{'open'})."\">";
	}
if ($main::session_id) {
	$session = "<param name=session value=\"sid=$main::session_id\">";
	}
if (!$access{'noconfig'}) {
	$config = "<param name=config value=\"$gconfig{'webprefix'}/config.cgi?$module_name\">";
	}
$iconsize = int($config{'iconsize'});
$root = join(" ", @allowed_roots);
$noroot = join(" ", @denied_roots);

foreach $d (@disallowed_buttons) {
	$disallowed .= "<param name=no_$d value=1>\n";
	}

# Create parameters for custom colours
foreach $k (keys %tconfig) {
	if ($k =~ /^applet_(.*)/) {
		$colours .= "<param name=$k value=\"$tconfig{$k}\">\n";
		}
	}

# Extract classes from jar, if we can
if ($config{'extract'} &&
    &has_command("unzip") && !-r "$module_root_directory/FileManager.class") {
	system("unzip file.jar >/dev/null 2>&1");
	}

print <<EOF;

<style>
body { margin: 0px; }
</style>

<script>
function upload(dir)
{
open("upform.cgi?dir="+escape(dir)+"&trust=$trust", "upload", "toolbar=no,menubar=no,scrollbar=no,width=550,height=230");
}
function htmledit(file, dir)
{
open("edit_html.cgi?file="+escape(file)+"&dir="+escape(dir)+"&trust=$trust", "html", "toolbar=no,menubar=no,scrollbar=no,width=800,height=600");
}
</script>

<applet code=FileManager name=FileManager archive=file.jar width=$w% height=$h% MAYSCRIPT>
<param name=root value="$root">
<param name=noroot value="$noroot">
<param name=follow value="$follow">
<param name=ro value="$access{'ro'}">
<param name=sharing value="$sharing">
<param name=mounting value="$mounting">
<param name=trust value="$trust">
<param name=goto value="$access{'goto'}">
<param name=iconsize value="$iconsize">
<param name=doarchive value="$archive">
<param name=unarchive value="$unarchive">
<param name=dostounix value="$dostounix">
<param name=fixed value="$config{'fixed'}">
<param name=small_fixed value="$config{'small_fixed'}">
<param name=canperms value="$canperms">
<param name=canusers value="$canusers">
<param name=contents value="$contents">
<param name=force_text value="$config{'force_text'}">
<param name=htmlexts value="$config{'htmlexts'}">
$config
$session
$open
$return
$disallowed
$colours
$text{'index_nojava'} <p>
$returnhtml
</applet>
EOF
&footer();


