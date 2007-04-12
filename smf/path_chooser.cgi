#!/usr/local/bin/perl
# chooser.cgi
# Outputs HTML for a frame-based path chooser 

require './smf-lib.pl';

&init_config();
&ReadParse();

if (defined($in{'path'})) {
	$path = $in{'path'};
	# +'s get converted to spaces, convert back
	$path =~ s/\s/+/g;
	if ($path =~ /^(\/.*)$/) {
		# path entered is valid
		$path=$1;
		}
} else {
	$path="/";
	}
$add = int($in{'add'});

$frame = $in{'frame'};
if ($frame eq "" ) {
	$frame = 0;
}

if ($in{'frame'} == 0) {
	# base frame
	&PrintHeader();
	print "<title>$text{'path_chooser_title'}</title>\n";
	print "<frameset rows='*,50'>\n";
	print "<frame marginwidth=10 marginheight=10 name=topframe ",
	    "src=\"path_chooser.cgi?frame=1&path=$path&add=$add\">\n";
	print "<frame marginwidth=10 marginheight=10 name=bottomframe ",
	    "src=\"path_chooser.cgi?frame=2&add=$add&path=$path\"",
	    "scrolling=no>\n";
	print "</frameset>\n";
	}
elsif ($in{'frame'} == 1) {
	# List of svcs
	&header();
	print <<EOF;
<script>
function pathclick(path, expand)
{
top.bottomframe.document.forms[0].path.value = path;
if (expand == 1) {
	location ="path_chooser.cgi?frame=1&add=$add&path="+path;
	}
}

</script>
EOF
	print "<b>", &text('path_chooser_path', $path),"</b>\n";
	print "<table>\n";
	# get file/dir list
	if (opendir(CURRDIR, $path)) {
		# remove extra trailing "/" if there.
		$fixed_filepath = $path;
		$fixed_filepath =~ s/(.*)\/$/$1/;
		foreach $f (readdir(CURRDIR)) {
			if ($f eq ".") {
				# skip
			} elsif ($f eq "..") {
				$uplevel = "$fixed_filepath";
				if ($uplevel =~ /^((\/[^\/]*)*)\/[^\/]*$/) {
					$uplevel = $1;
					}
				if ($uplevel eq "") {
					$uplevel = "/";
					}
				$uplevel = &urlize($uplevel);
				push(@pathlist,
"<td><a href='javascript:pathclick(\"$uplevel\",1)'><img border=0 width=30 height=30 src=\"images/uplevel.gif\"></a></td><td><a href='javascript:pathclick(\"$uplevel\",1)'>..</a></td>");
			} else {
				$expand = 0;
				$img = "images/file.gif";
				# is this a file or a dir?
				if (opendir(DISCARD, "$fixed_filepath/$f")) {
					close(DISCARD);
					$expand = 1;
					$img = "images/dir.gif";
					}
				$newpath = &urlize("$fixed_filepath/$f");
				push(@pathlist,
"<td><a href='javascript:pathclick(\"$newpath\",$expand)'><img border=0 width=30 height=30 src=$img></a></td><td><a href='javascript:pathclick(\"$newpath\",$expand)'>$f</a></td>");
				}
			}
		closedir(CURRDIR);
		}
	foreach $p (@pathlist) {
		print "<tr>\n";
		print "$p";
		print "</tr>\n";
		}
	print "</table>\n";
	&footer();
	}
elsif ($in{'frame'} == 2) {
	# Current path and OK/cancel buttons
	&header();
	print <<EOF;
<script>
function pathchosen()
{
if ($add == 0) {
	top.opener.ifield.value =
	 "file://localhost"+document.forms[0].path.value;
	}
else {
	if (top.opener.ifield.value != "") {
		top.opener.ifield.value += " ";
		}
	top.opener.ifield.value +=
	 "file://localhost"+document.forms[0].path.value;
	}
top.close();
}
</script>
EOF
	print "<table width=100%><tr><td>\n";
	print "<form onSubmit='pathchosen(); return false'>\n";
	print
	 "<input name=path size=45 value=\"\">\n";
	print
	 "<input type=\"submit\" value=\"$text{'path_chooser_ok'}\">\n";
	print "</form>\n";
	print "</td><td>\n";
	print "<form>";
	print
"<input type=\"button\" onClick='top.close()' value=\"$text{'path_chooser_cancel'}\">";
	print "</form>";
	print "</td></tr></table></form>\n";
	&footer();
	}
