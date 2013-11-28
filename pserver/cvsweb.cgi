#!/usr/local/bin/perl
#
# cvsweb - a CGI interface to CVS trees.
#
# Written in their spare time by
#             Bill Fenner      <fenner@FreeBSD.org>   (original work)
# extended by Henner Zeller    <zeller@think.de>,
#             Henrik Nordström <hno@hem.passagen.se> 
#             Ken Coar         <coar@Apache.Org>
#             Dick Balaska     <dick@buckosoft.com>
#             Jens-Uwe Mager   <jum@helios.de>
#
# Based on:
# * Bill Fenners cvsweb.cgi revision 1.28 available from:
#   http://www.FreeBSD.org/cgi/cvsweb.cgi/www/en/cgi/cvsweb.cgi
#
# Copyright (c) 1996-1998 Bill Fenner
#           (c) 1998-1999 Henner Zeller
#	    (c) 1999      Henrik Nordström
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# $Id: cvsweb.cgi,v 1.112 2001/07/24 13:03:16 hzeller Exp $
#
###
require './pserver-lib.pl';
$access{'cvsweb'} || &error($text{'cvsweb_ecannot'});

use vars qw (
    $config $allow_version_select $verbose
    %CVSROOT %CVSROOTdescr %MIRRORS %DEFAULTVALUE %ICONS %MTYPES
    %alltags @tabcolors %fileinfo %tags @branchnames %nameprinted
    %symrev %revsym @allrevisions %date %author @revdisplayorder
    @revisions %state %difflines %log %branchpoint @revorder
    $checkoutMagic $doCheckout $scriptname $scriptwhere
    $where $Browser $nofilelinks $maycompress @stickyvars
    %input $query $barequery $sortby $bydate $byrev $byauthor
    $bylog $byfile $hr_default $logsort $cvstree $cvsroot
    $mimetype $defaultTextPlain $defaultViewable $allow_compress
    $GZIPBIN $backicon $diricon $fileicon $fullname $newname
    $cvstreedefault $body_tag $logo $defaulttitle $address
    $backcolor $long_intro $short_instruction $shortLogLen
    $show_author $dirtable $tablepadding $columnHeaderColorDefault
    $columnHeaderColorSorted $hr_breakable $hr_funout $hr_ignwhite
    $hr_ignkeysubst $diffcolorHeading $diffcolorEmpty $diffcolorRemove
    $diffcolorChange $diffcolorAdd $diffcolorDarkChange $difffontface
    $difffontsize $inputTextSize $mime_types $allow_annotate
    $allow_markup $use_java_script $open_extern_window
    $extern_window_width $extern_window_height $edit_option_form
    $checkout_magic $show_subdir_lastmod $show_log_in_markup $v
    $navigationHeaderColor $tableBorderColor $markupLogColor
    $tabstop $state $annTable $sel $curbranch @HideModules @DissallowRead
    $module $use_descriptions %descriptions @mytz $dwhere $moddate
    $use_moddate $has_zlib $gzip_open
);

##### prototype declarations ########
sub printDiffSelect($);
sub findLastModifiedSubdirs(@);
sub htmlify($);
sub spacedHtmlText($);
sub link($$);
sub revcmp($$);
sub fatal($$);
sub credirect($);
sub safeglob($);
sub getMimeTypeFromSuffix($);
sub doAnnotate ($$);
sub doCheckout($$);
sub cvswebMarkup($$$);
sub viewable($);
sub doDiff($$$$$$);
sub getDirLogs($$@);
sub readLog($;$);
sub printLog($;$);
sub doLog($);
sub flush_diff_rows ($$$$);
sub human_readable_diff($);
sub navigateHeader ($$$$$);
sub plural_write ($$);
sub readableTime ($$);
sub clickablePath($$);
sub chooseCVSRoot();
sub chooseMirror();
sub fileSortCmp();
sub download_url($$$);
sub download_link($$$$);
sub toggleQuery($$);
sub urlencode($);
sub http_header(;$);
sub html_header($);
sub html_footer();
sub link_tags($);
sub forbidden_module($);
sub forbidden_file($);
sub checkForbidden($@);
sub gzipclose();
sub MAGIC1();
sub MAGIC2();
sub OSCODE();

##### Start of Configuration Area ########
# == EDIT this == 
# User configuration is stored in
$config = "./cvsweb.conf";

# == Configuration defaults ==
# Defaults for configuration variables that shouldn't need
# to be configured..
$allow_version_select = 1;

##### End of Configuration Area   ########

######## Configuration variables #########
# These are defined to allow checking with perl -cw
%CVSROOT = %MIRRORS = %DEFAULTVALUE = %ICONS = %MTYPES =
%tags = %alltags = @tabcolors = %fileinfo = ();
$cvstreedefault = $body_tag = $logo = $defaulttitle = $address =
$backcolor = $long_intro = $short_instruction = $shortLogLen =
$show_author = $dirtable = $tablepadding = $columnHeaderColorDefault =
$columnHeaderColorSorted = $hr_breakable = $hr_funout = $hr_ignwhite =
$hr_ignkeysubst = $diffcolorHeading = $diffcolorEmpty = $diffcolorRemove =
$diffcolorChange = $diffcolorAdd = $diffcolorDarkChange = $difffontface =
$difffontsize = $inputTextSize = $mime_types = $allow_annotate =
$allow_markup = $use_java_script = $open_extern_window =
$extern_window_width = $extern_window_height = $edit_option_form =
$checkout_magic = $show_subdir_lastmod = $show_log_in_markup = $v =
$navigationHeaderColor = $tableBorderColor = $markupLogColor = 
$tabstop = $use_moddate = $moddate = $gzip_open = undef;

##### End of configuration variables #####

use Time::Local;
use IPC::Open2;

# Check if the zlib C library interface is installed, and if yes
# we can avoid using the extra gzip process.
eval {
	require Compress::Zlib;
};
$has_zlib = !$@;

$verbose = $v;
$checkoutMagic = "~checkout~";
$where = defined($ENV{'PATH_INFO'}) ? $ENV{'PATH_INFO'} : "";
$doCheckout = ($where =~ /^\/$checkoutMagic/);
$where =~ s|^/($checkoutMagic)?||;
$where =~ s|/+$||;
$where =~ s|^/+||;
($scriptname = $ENV{'SCRIPT_NAME'}) =~ s|^/?|/|;
$scriptname =~ s|/+$||;
if ($where) {
    $scriptwhere = $scriptname . '/' . urlencode($where);
}
else {
    $scriptwhere = $scriptname;
}
$scriptwhere =~ s|/+$||;

# in lynx, it it very annoying to have two links
# per file, so disable the link at the icon
# in this case:
$Browser = $ENV{'HTTP_USER_AGENT'};
$nofilelinks = ($Browser =~ m'^Lynx/');

# newer browsers accept gzip content encoding
# and state this in a header
# (netscape did always but didn't state it)
# It has been reported that these
#  braindamaged MS-Internet Exploders claim that they
# accept gzip .. but don't in fact and
# display garbage then :-/
# Turn off gzip if running under mod_perl and no zlib is available,
# piping does not work as expected inside the server.
$maycompress = (((defined($ENV{'HTTP_ACCEPT_ENCODING'})
		 && $ENV{'HTTP_ACCEPT_ENCODING'} =~ m|gzip|)
		|| $Browser =~ m%^Mozilla/3%)
	       && ($Browser !~ m/MSIE/)
	       && !(defined($ENV{'MOD_PERL'}) && !$has_zlib));
$maycompress = 0;

# put here the variables we need in order
# to hold our state - they will be added (with
# their current value) to any link/query string
# you construct
@stickyvars = qw(cvsroot hideattic sortby logsort f only_with_tag);

if (-f $config) {
    do "$config";
}
else {
   &fatal("500 Internal Error",
	  'Configuration not found.  Set the variable <code>$config</code> '
          . 'in cvsweb.cgi, or the environment variable '
          . '<code>CVSWEB_CONFIG</code>, to your <b>cvsweb.conf</b> '
          . 'configuration file first.');
}

undef %input;
if ($query = $ENV{'QUERY_STRING'}) {
    foreach (split(/&/, $query)) {
	y/+/ /;
	s/%(..)/sprintf("%c", hex($1))/ge;	# unquote %-quoted
	if (/(\S+)=(.*)/) {
	    $input{$1} = $2 if ($2 ne "");
	}
	else {
	    $input{$_}++;
	}
    }
}

# For backwards compability, set only_with_tag to only_on_branch if set. 
$input{only_with_tag} = $input{only_on_branch}
    if (defined($input{only_on_branch}));

foreach (keys %DEFAULTVALUE)
{
    # replace not given parameters with the default parameters
    if (!defined($input{$_}) || $input{$_} eq "") {
	# Empty Checkboxes in forms return -- nothing. So we define a helper
	# variable in these forms (copt) which indicates that we just set
	# parameters with a checkbox
	if (!defined($input{"copt"})) {
	    # 'copt' isn't defined --> empty input is not the result
	    # of empty input checkbox --> set default
	    $input{$_} = $DEFAULTVALUE{$_} if (defined($DEFAULTVALUE{$_}));
	}
	else {
	    # 'copt' is defined -> the result of empty input checkbox
	    # -> set to zero (disable) if default is a boolean (0|1).
	    $input{$_} = 0
		if (defined($DEFAULTVALUE{$_})
		    && ($DEFAULTVALUE{$_} eq "0" || $DEFAULTVALUE{$_} eq "1"));
	}
    }
}
    
$barequery = "";
foreach (@stickyvars) {
    # construct a query string with the sticky non default parameters set
	if (defined($input{$_}) && ($input{$_} ne "") && 
	    (!defined($DEFAULTVALUE{$_}) || $input{$_} ne $DEFAULTVALUE{$_})) {
	if ($barequery) {
	    $barequery = $barequery . "&amp;";
	}
	my $thisval = urlencode($_) . "=" . urlencode($input{$_});
	$barequery .= $thisval;
    }
}
# is there any query ?
if ($barequery) {
    $query = "?$barequery";
    $barequery = "&amp;" . $barequery;
}
else {
    $query = "";
}

# get actual parameters
$sortby = $input{"sortby"};
$bydate = 0;
$byrev = 0;
$byauthor = 0;
$bylog = 0;
$byfile = 0;
if ($sortby eq "date") {
    $bydate = 1;
}
elsif ($sortby eq "rev") {
    $byrev = 1;
}
elsif ($sortby eq "author") {
    $byauthor = 1;
}
elsif ($sortby eq "log") {
    $bylog = 1;
}
else {
    $byfile = 1;
}

$hr_default = $input{'f'} eq 'h';

$logsort = $input{"logsort"};


## Default CVS-Tree
if (!defined($CVSROOT{$cvstreedefault})) {
   &fatal("500 Internal Error",
	  "<code>\$cvstreedefault</code> points to a repository ($cvstreedefault)"
	  . "not defined in <code>%CVSROOT</code> "
	  . "(edit your configuration file $config)");
}
$cvstree = $cvstreedefault;
$cvsroot = $CVSROOT{"$cvstree"};

# alternate CVS-Tree, configured in cvsweb.conf
if ($input{'cvsroot'}) {
    if ($CVSROOT{$input{'cvsroot'}}) {
	$cvstree = $input{'cvsroot'};
	$cvsroot = $CVSROOT{"$cvstree"};
    }
}

# create icons out of description
foreach my $k (keys %ICONS) {
    no strict 'refs';
    my ($itxt,$ipath,$iwidth,$iheight) = @{$ICONS{$k}};
    if ($ipath) {
	$ {"${k}icon"} = "<IMG SRC=\"$ipath\" ALT=\"$itxt\" BORDER=\"0\" WIDTH=\"$iwidth\" HEIGHT=\"$iheight\">";
    }
    else {
	$ {"${k}icon"} = $itxt;
    }
}

# Do some special configuration for cvstrees
do "$config-$cvstree" if (-f "$config-$cvstree");

$fullname = $cvsroot . '/' . $where;
$mimetype = &getMimeTypeFromSuffix ($fullname);
$defaultTextPlain = ($mimetype eq "text/plain");
$defaultViewable = $allow_markup && viewable($mimetype);

# search for GZIP if compression allowed
# We've to find out if the GZIP-binary exists .. otherwise
# ge get an Internal Server Error if we try to pipe the
# output through the nonexistent gzip .. 
# any more elegant ways to prevent this are welcome!
if ($allow_compress && $maycompress && !$has_zlib) {
    foreach (split(/:/, $ENV{PATH})) {
	if (-x "$_/gzip") {
	    $GZIPBIN = "$_/gzip";
	    last;
	}
    }
}

if (-d $fullname) {
    #
    # ensure, that directories always end with (exactly) one '/'
    # to allow relative URL's. If they're not, make a credirect.
    ##
    my $pathinfo = defined($ENV{'PATH_INFO'}) ? $ENV{'PATH_INFO'} : "";
    if (!($pathinfo =~ m|/$|) || ($pathinfo =~ m |/{2,}$|)) {
	credirect ($scriptwhere . '/' . $query);
    }
    else {
	$where .= '/';
	$scriptwhere .= '/';
    }
}

if (!-d $cvsroot) {
    &fatal("500 Internal Error",'$CVSROOT not found!<P>The server on which the CVS tree lives is probably down.  Please try again in a few minutes.');
}

#
# See if the module is in our forbidden list.
#
$where =~ m:([^/]*):;
$module = $1;
if ($module && &forbidden_module($module)) {
    &fatal("403 Forbidden", "Access to $where forbidden.");
}
##############################
# View a directory
###############################
elsif (-d $fullname) {
	my $dh = do {local(*DH);};
	opendir($dh, $fullname) || &fatal("404 Not Found","$where: $!");
	my @dir = readdir($dh);
	closedir($dh);
	my @subLevelFiles = findLastModifiedSubdirs(@dir)
	    if ($show_subdir_lastmod);
	getDirLogs($cvsroot,$where,@subLevelFiles);

	if ($where eq '/') {
	    html_header("$defaulttitle");
	    print $long_intro;
	}
	else {
	    html_header("$where");
	    print $short_instruction;
	}

	my $descriptions;
	if (($use_descriptions) && open (DESC, "<$cvsroot/CVSROOT/descriptions")) {
	    while (<DESC>) {
		chomp;
		my ($dir,$description) = /(\S+)\s+(.*)/;
		$descriptions{$dir} = $description;
	    }
	}

	print "<P><a name=\"dirlist\"></a>\n";
	# give direct access to dirs
	if ($where eq '/') {
	    chooseMirror();
	    chooseCVSRoot();
	}
	else {
	    print "<p>Current directory: <b>", &clickablePath($where,0), "</b>\n";

	    print "<P>Current tag: <B>", $input{only_with_tag}, "</b>\n" if
		$input{only_with_tag};

	}
	 

	print "<HR NOSHADE>\n";
	# Using <MENU> in this manner violates the HTML2.0 spec but
	# provides the results that I want in most browsers.  Another
	# case of layout spooging up HTML.
	
	my $infocols = 0;
	if ($dirtable) {
	    if (defined($tableBorderColor)) {
		# Can't this be done by defining the border for the inner table?
		print "<table border=0 cellpadding=0 width=\"100%\"><tr><td bgcolor=\"$tableBorderColor\">";
	    }
	    print "<table  width=\"100%\" border=0 cellspacing=1 cellpadding=$tablepadding>\n";
	    $infocols++;
	    print "<tr><th align=left bgcolor=\"" . (($byfile) ? 
						   $columnHeaderColorSorted : 
						   $columnHeaderColorDefault) . "\">";
	    print "<a href=\"./" . &toggleQuery("sortby","file") .
		"#dirlist\">" if (!$byfile);
	    print "File";
	    print "</a>" if (!$byfile);
	    print "</th>";
	    # do not display the other column-headers, if we do not have any files
	    # with revision information:
	    if (scalar(%fileinfo)) {
		$infocols++;
		print "<th align=left bgcolor=\"" . (($byrev) ? 
						   $columnHeaderColorSorted : 
						   $columnHeaderColorDefault) . "\">";
		print "<a href=\"./" . &toggleQuery ("sortby","rev") .
		    "#dirlist\">" if (!$byrev);
		print "Rev.";
		print "</a>" if (!$byrev);
		print "</th>";
		$infocols++;
		print "<th align=left bgcolor=\"" . (($bydate) ? 
						   $columnHeaderColorSorted : 
						   $columnHeaderColorDefault) . "\">";
		print "<a href=\"./" . &toggleQuery ("sortby","date") .
		    "#dirlist\">" if (!$bydate);
		print "Age";
		print "</a>" if (!$bydate);
		print "</th>";
		if ($show_author) {
		    $infocols++;
		    print "<th align=left bgcolor=\"" . (($byauthor) ? 
						   $columnHeaderColorSorted : 
						   $columnHeaderColorDefault) . "\">";
		    print "<a href=\"./" . &toggleQuery ("sortby","author") .
			    "#dirlist\">" if (!$byauthor);
		    print "Author";
		    print "</a>" if (!$byauthor);
		    print "</th>";
		}
		$infocols++;
		print "<th align=left bgcolor=\"" . (($bylog) ? 
					       $columnHeaderColorSorted : 
					       $columnHeaderColorDefault) . "\">";
		print "<a href=\"./", toggleQuery("sortby","log"), "#dirlist\">" if (!$bylog);
		print "Last log entry";
		print "</a>" if (!$bylog);
		print "</th>";
	    }
	    elsif ($use_descriptions) {
		print "<th align=left bgcolor=\"". $columnHeaderColorDefault . "\">";
		print "Description";
		$infocols++;
	    }
	    print "</tr>\n";
	}
	else {
	    print "<menu>\n";
	}
	my $dirrow = 0;
	
	my $i;
	lookingforattic:
	for ($i = 0; $i <= $#dir; $i++) {
		if ($dir[$i] eq "Attic") {
		    last lookingforattic;
		}
	}
	if (!$input{'hideattic'} && ($i <= $#dir) &&
	    opendir($dh, $fullname . "/Attic")) {
	    splice(@dir, $i, 1,
			grep((s|^|Attic/|,!m|/\.|), readdir($dh)));
	    closedir($dh);
	}

	my $hideAtticToggleLink = "<a href=\"./" . 
	        &toggleQuery ("hideattic") .
		"#dirlist\">[Hide]</a>" if (!$input{'hideattic'});

	# Sort without the Attic/ pathname.
	# place directories first

	my $attic;
	my $url;
	my $fileurl;
	my $filesexists;
	my $filesfound;

	foreach (sort { &fileSortCmp } @dir) {
	    if ($_ eq '.') {
		next;
	    }
	    # ignore CVS lock and stale NFS files
	    next if (/^#cvs\.|^,|^\.nfs/);

	    # Check whether to show the CVSROOT path
	    next if ($input{'hidecvsroot'} && ($_ eq 'CVSROOT'));

	    # Check whether the module is in the restricted list
	    next if ($_ && &forbidden_module($_));

	    # Ignore non-readable files
	    next if ($input{'hidenonreadable'} && !(-r "$fullname/$_"));

	    if (s|^Attic/||) {
		$attic  = " (in the Attic)&nbsp;" . $hideAtticToggleLink;
	    }
	    else {
		$attic = "";
	    }

	    if ($_ eq '..' || -d "$fullname/$_") {
		next if ($_ eq '..' && $where eq '/');
		my ($rev,$date,$log,$author,$filename);
		($rev,$date,$log,$author,$filename) = @{$fileinfo{$_}}
		    if (defined($fileinfo{$_}));
		print "<tr bgcolor=\"" . @tabcolors[$dirrow%2] . "\"><td>" if ($dirtable);
		if ($_ eq '..') {
		    $url = "../" . $query;
		    if ($nofilelinks) {
			print $backicon;
		    }
		    else {
			print &link($backicon,$url);
		    }
		    print " ", &link("Previous Directory",$url);
		}
		else {
		    $url = urlencode($_) . '/' . $query;
		    print "<A NAME=\"$_\"></A>";
		    if ($nofilelinks) {
			print $diricon;
		    }
		    else {
			print &link($diricon,$url);
		    }
		    print " ", &link($_ . "/", $url), $attic;
		    if ($_ eq "Attic") {
			print "&nbsp; <a href=\"./" . 
			    &toggleQuery ("hideattic") .
				"#dirlist\">[Don't hide]</a>";
		    }
		} 
		# Show last change in dir
		if ($filename) {
		    print "</td><td>&nbsp;</td><td>&nbsp;" if ($dirtable);
		    if ($date) {
			print " <i>" . readableTime(time() - $date,0) . "</i>";
		    }
		    if ($show_author) {
			print "</td><td>&nbsp;" if ($dirtable);
			print $author;
		    }
		    print "</td><td>&nbsp;" if ($dirtable);
		    $filename =~ s%^[^/]+/%%;
		    print "$filename/$rev";
		    print "<BR>" if ($dirtable);
		    if ($log) {
			print "&nbsp;<font size=-1>"
			    . &htmlify(substr($log,0,$shortLogLen));
			if (length $log > 80) {
			    print "...";
			}
			print "</font>";
		    }
		}
		else {
		    my ($dwhere) = ($where ne "/" ? $where : "") . $_;
		    if ($use_descriptions && defined $descriptions{$dwhere}) {
			print "<TD COLSPAN=" . ($infocols-1) . ">&nbsp;" if $dirtable;
			print $descriptions{$dwhere};
		    } elsif ($dirtable && $infocols > 1) {
			# close the row with the appropriate number of
			# columns, so that the vertical seperators are visible
			my($cols) = $infocols;
			while ($cols > 1) {
			    print "</td><td>&nbsp;";
			    $cols--;
			}
		    }
		}
		if ($dirtable) {
		    print "</td></tr>\n";
		}
		else {
		    print "<br>\n";
		}
		$dirrow++;
	    }
	    elsif (s/,v$//) {
		$fileurl = ($attic ? "Attic/" : "") . urlencode($_);
		$url = $fileurl . $query;
		my $rev = '';
		my $date = '';
		my $log = '';
		my $author = '';
		$filesexists++;
		next if (!defined($fileinfo{$_}));
		($rev,$date,$log,$author) = @{$fileinfo{$_}};
		$filesfound++;
		print "<tr bgcolor=\"" . @tabcolors[$dirrow%2] . "\"><td>" if ($dirtable);
		print "<A NAME=\"$_\"></A>";
		if ($nofilelinks) {
		    print $fileicon;
		}
		else {
		    print &link($fileicon,$url);
		}
		print " ", &link($_, $url), $attic;
		print "</td><td>&nbsp;" if ($dirtable);
		download_link($fileurl,
			$rev, $rev, 
			$defaultViewable ? "text/x-cvsweb-markup" : undef);
		print "</td><td>&nbsp;" if ($dirtable);
		if ($date) {
		    print " <i>" . readableTime(time() - $date,0) . "</i>";
		}
		if ($show_author) {
		    print "</td><td>&nbsp;" if ($dirtable);
		    print $author;
		}
		print "</td><td>&nbsp;" if ($dirtable);
		if ($log) {
		    print " <font size=-1>" . &htmlify(substr($log,0,$shortLogLen));
		    if (length $log > 80) {
			print "...";
		    }
		    print "</font>";
		}
		print "</td>" if ($dirtable);
		print (($dirtable) ? "</tr>" : "<br>");
		$dirrow++;
	    }
	    print "\n";
	}
	if ($dirtable && defined($tableBorderColor)) {
	    print "</td></tr></table>";
	}
	print "". ($dirtable == 1) ? "</table>" : "</menu>" . "\n";
	
	if ($filesexists && !$filesfound) {
	    print "<P><B>NOTE:</B> There are $filesexists files, but none matches the current tag ($input{only_with_tag})\n";
	}
	if ($input{only_with_tag} && (!%tags || !$tags{$input{only_with_tag}})) {
	    %tags = %alltags
	}
	if (scalar %tags 
	    || $input{only_with_tag} 
	    || $edit_option_form
	    || defined($input{"options"})) {
	    print "<hr size=1 NOSHADE>";
	}

	if (scalar %tags || $input{only_with_tag}) {
	    print "<FORM METHOD=\"GET\" ACTION=\"./\">\n";
	    foreach my $var (@stickyvars) {
		print "<INPUT TYPE=HIDDEN NAME=\"$var\" VALUE=\"$input{$var}\">\n"
		    if (defined($input{$var})
			&& (!defined($DEFAULTVALUE{$var})
			    || $input{$var} ne $DEFAULTVALUE{$var})
			&& $input{$var} ne ""
			&& $var ne "only_with_tag");
	    }
	    print "Show only files with tag:\n";
	    print "<SELECT NAME=only_with_tag";
	    print " onchange=\"submit()\"" if ($use_java_script);
	    print ">";
	    print "<OPTION VALUE=\"\">All tags / default branch</OPTION>\n";
	    foreach my $tag (reverse sort { lc $a cmp lc $b } keys %tags) {
		print "<OPTION",defined($input{only_with_tag}) && 
		       $input{only_with_tag} eq $tag ? " SELECTED":"",
		       ">$tag</OPTION>\n";
	    }
	    print "</SELECT>\n";
	    print "<INPUT TYPE=SUBMIT VALUE=\"Go\">\n";
	    print "</FORM>\n";
	}
	my $formwhere = $scriptwhere;
	$formwhere =~ s|Attic/?$|| if ($input{'hideattic'});

	if ($edit_option_form || defined($input{"options"})) {
	    print "<FORM METHOD=\"GET\" ACTION=\"${formwhere}\">\n";
	    print "<INPUT TYPE=HIDDEN NAME=\"copt\" VALUE=\"1\">\n";
	    if ($cvstree ne $cvstreedefault) {
		print "<INPUT TYPE=HIDDEN NAME=\"cvsroot\" VALUE=\"$cvstree\">\n";
	    }
	    print "<center><table cellpadding=0 cellspacing=0>";
	    print "<tr bgcolor=\"$columnHeaderColorDefault\"><th colspan=2>Preferences</th></tr>";
	    print "<tr><td>Sort files by <SELECT name=\"sortby\">";
	    print "<OPTION VALUE=\"\">File</OPTION>";
	    print "<OPTION",$bydate ? " SELECTED" : ""," VALUE=date>Age</OPTION>";
	    print "<OPTION",$byauthor ? " SELECTED" : ""," VALUE=author>Author</OPTION>"
		if ($show_author);
	    print "<OPTION",$byrev ? " SELECTED" : ""," VALUE=rev>Revision</OPTION>";
	    print "<OPTION",$bylog ? " SELECTED" : ""," VALUE=log>Log message</OPTION>";
	    print "</SELECT></td>";
	    print "<td>revisions by: \n";
	    print "<SELECT NAME=logsort>\n";
	    print "<OPTION VALUE=cvs",$logsort eq "cvs" ? " SELECTED" : "", ">Not sorted</OPTION>";
	    print "<OPTION VALUE=date",$logsort eq "date" ? " SELECTED" : "", ">Commit date</OPTION>";
	    print "<OPTION VALUE=rev",$logsort eq "rev" ? " SELECTED" : "", ">Revision</OPTION>";
	    print "</SELECT></td></tr>";
	    print "<tr><td>Diff format: ";
	    printDiffSelect(0);
	    print "</td>";
	    print "<td>Show Attic files: ";
	    print "<INPUT NAME=hideattic TYPE=CHECKBOX", $input{'hideattic'}?" CHECKED":"", 
	    "></td></tr>\n";
	    print "<tr><td align=center colspan=2><input type=submit value=\"Change Options\">";
	    print "</td></tr></table></center></FORM>\n";
	}
	print &html_footer;
	print "</BODY></HTML>\n";
    } 

###############################
# View Files
###############################
    elsif (-f $fullname . ',v') {
	if (defined($input{'rev'}) || $doCheckout) {
	    &doCheckout($fullname, $input{'rev'});
	    gzipclose();
	    exit;
	}
	if (defined($input{'annotate'}) && $allow_annotate) {
	    &doAnnotate($input{'annotate'});
	    gzipclose();
	    exit;
	}
	if (defined($input{'r1'}) && defined($input{'r2'})) {
	    &doDiff($fullname, $input{'r1'}, $input{'tr1'},
		    $input{'r2'}, $input{'tr2'}, $input{'f'});
	    gzipclose();
	    exit;
	}
	print("going to dolog($fullname)\n") if ($verbose);
	&doLog($fullname);
##############################
# View Diff
##############################
    }
    elsif ($fullname =~ s/\.diff$// && -f $fullname . ",v" &&
	   $input{'r1'} && $input{'r2'}) {

	# $where-diff-removal if 'cvs rdiff' is used
	# .. but 'cvs rdiff'doesn't support some options
	# rcsdiff does (-w and -p), so it is disabled
	# $where =~ s/\.diff$//;

	# Allow diffs using the ".diff" extension
	# so that browsers that default to the URL
	# for a save filename don't save diff's as
	# e.g. foo.c
	&doDiff($fullname, $input{'r1'}, $input{'tr1'},
		$input{'r2'}, $input{'tr2'}, $input{'f'});
	gzipclose();
	exit;
    }
    elsif (($newname = $fullname) =~ s|/([^/]+)$|/Attic/$1| &&
	   -f $newname . ",v") {
	# The file has been removed and is in the Attic.
	# Send a credirect pointing to the file in the Attic.
	(my $newplace = $scriptwhere) =~ s|/([^/]+)$|/Attic/$1|;
	&credirect($newplace . "?" . $ENV{QUERY_STRING});
	exit;
    }
    elsif (0 && (my @files = &safeglob($fullname . ",v"))) {
	http_header("text/plain");
	print "You matched the following files:\n";
	print join("\n", @files);
	# Find the tags from each file
	# Display a form offering diffs between said tags
    }
    else {
	my $fh = do {local(*FH);};
	my ($xtra, $module);
	# Assume it's a module name with a potential path following it.
	$xtra = $& if (($module = $where) =~ s|/.*||);
	# Is there an indexed version of modules?
	if (open($fh, "$cvsroot/CVSROOT/modules")) {
	    while (<$fh>) {
		if (/^(\S+)\s+(\S+)/o && $module eq $1
		    && -d "${cvsroot}/$2" && $module ne $2) {
		    &credirect($scriptname . '/' . $2 . $xtra);
		}
	    }
	}
	&fatal("404 Not Found","$where: no such file or directory");
    }

gzipclose();
## End MAIN

sub printDiffSelect($) {
    my ($use_java_script) = @_;
    $use_java_script = 0 if (!defined($use_java_script));
    my ($f) = $input{'f'};
    print "<SELECT NAME=\"f\"";
    print " onchange=\"submit()\"" if ($use_java_script);
    print ">\n";
    print "<OPTION VALUE=h",$f eq "h" ? " SELECTED" : "", ">Colored Diff</OPTION>";
    print "<OPTION VALUE=H",$f eq "H" ? " SELECTED" : "", ">Long Colored Diff</OPTION>";
    print "<OPTION VALUE=u",$f eq "u" ? " SELECTED" : "", ">Unidiff</OPTION>";
    print "<OPTION VALUE=c",$f eq "c" ? " SELECTED" : "", ">Context Diff</OPTION>";
    #print "<OPTION VALUE=s",$f eq "s" ? " SELECTED" : "", ">Side by Side</OPTION>";
    print "</SELECT>";
}

sub findLastModifiedSubdirs(@) {
    my (@dirs) = @_;
    my ($dirname, @files);

    foreach $dirname (@dirs) {
	next if ($dirname eq ".");
	next if ($dirname eq "..");
	my ($dir) = "$fullname/$dirname";
	next if (!-d $dir);

	my ($lastmod) = undef;
	my ($lastmodtime) = undef;
	my $dh = do {local(*DH);};

	opendir($dh,$dir) || next;
	my (@filenames) = readdir($dh);
	closedir($dh);

	foreach my $filename (@filenames) {
	    $filename = "$dirname/$filename";
	    my ($file) = "$fullname/$filename";
	    next if ($filename !~ /,v$/ || !-f $file);
	    $filename =~ s/,v$//;
	    my $modtime = -M $file;
	    if (!defined($lastmod) || $modtime < $lastmodtime) {
		$lastmod = $filename;
		$lastmodtime = $modtime;
	    }
	}
	push(@files, $lastmod) if (defined($lastmod));
    }
    return @files;
}

sub htmlify($) {
	my($string) = @_;

	# Special Characters; RFC 1866
	$string =~ s/&/&amp;/g;
	$string =~ s/\"/&quot;/g; 
	$string =~ s/</&lt;/g;
	$string =~ s/>/&gt;/g;

	# get URL's as link ..
	$string =~ s§(http|ftp|https)(://[-a-zA-Z0-9%.~:_/]+)([?&]([-a-zA-Z0-9%.~:_]+)=([-a-zA-Z0-9%.~:_])+)*§<A HREF="$1$2$3">$1$2$3</A>§;
	# get e-mails as link
	$string =~ s§([-a-zA-Z0-9_.]+@([-a-zA-Z0-9]+\.)+[A-Za-z]{2,4})§<A HREF="mailto:$1">$1</A>§;

	return $string;
}

sub spacedHtmlText($) {
	my($string) = @_;

	# Cut trailing spaces
	s/\s+$//;

	# Expand tabs
	$string =~ s/\t+/' ' x (length($&) * $tabstop - length($`) % $tabstop)/e
	    if (defined($tabstop));

	# replace <tab> and <space> (§ is to protect us from htmlify)
	# gzip can make excellent use of this repeating pattern :-)
	$string =~ s/§/§%/g; #protect our & substitute
	if ($hr_breakable) {
	    # make every other space 'breakable'
	    $string =~ s/	/ §nbsp; §nbsp; §nbsp; §nbsp;/g;    # <tab>
	    $string =~ s/  / §nbsp;/g;                              # 2 * <space>
	    # leave single space as it is
	}
	else {
	    $string =~ s/	/§nbsp;§nbsp;§nbsp;§nbsp;§nbsp;§nbsp;§nbsp;§nbsp;/g; 
	    $string =~ s/ /§nbsp;/g;
	}

	$string = htmlify($string);

	# unescape
	$string =~ s/§([^%])/&$1/g;
	$string =~ s/§%/§/g;

	return $string;
}

sub link($$) {
	my($name, $where) = @_;

	return "<A HREF=\"$where\">$name</A>\n";
}

sub revcmp($$) {
	my($rev1, $rev2) = @_;
	my(@r1) = split(/\./, $rev1);
	my(@r2) = split(/\./, $rev2);
	my($a,$b);

	while (($a = shift(@r1)) && ($b = shift(@r2))) {
	    if ($a != $b) {
		return $a <=> $b;
	    }
	}
	if (@r1) { return 1; }
	if (@r2) { return -1; }
	return 0;
}

sub fatal($$) {
	my($errcode, $errmsg) = @_;
	if (defined($ENV{'MOD_PERL'})) {
		Apache->request->status((split(/ /, $errcode))[0]);
	}
	else {
		print "Status: $errcode\n";
	}
	html_header("Error");
	print "Error: $errmsg\n";
	print &html_footer;
	exit(1);
}

sub credirect($) {
	my($url) = @_;
	if (defined($ENV{'MOD_PERL'})) {
		Apache->request->status(301);
		Apache->request->header_out(Location => $url);
	}
	else {
		print "Status: 301 Moved\r\n";
		print "Location: $url\r\n";
	}
	html_header("Moved");
	print "This document is located <A HREF=$url>here</A>.\n";
	print &html_footer;
	exit(1);
}

sub safeglob($) {
	my ($filename) = @_;
	my ($dirname);
	my (@results);
	my $dh = do {local(*DH);};

	($dirname = $filename) =~ s|/[^/]+$||;
	$filename =~ s|.*/||;

	if (opendir($dh, $dirname)) {
		my $glob = $filename;
		my $t;
	#	transform filename from glob to regex.  Deal with:
	#	[, {, ?, * as glob chars
	#	make sure to escape all other regex chars
		$glob =~ s/([\.\(\)\|\+])/\\$1/g;
		$glob =~ s/\*/.*/g;
		$glob =~ s/\?/./g;
		$glob =~ s/{([^}]+)}/($t = $1) =~ s-,-|-g; "($t)"/eg;
		foreach (readdir($dh)) {
			if (/^${glob}$/) {
				push(@results, $dirname . "/" .$_);
			}
		}
		closedir($dh);
	}

	@results;
}

sub getMimeTypeFromSuffix($) {
    my ($fullname) = @_;
    my ($mimetype, $suffix);
    my $fh = do {local(*FH);};

    ($suffix = $fullname) =~ s/^.*\.([^.]*)$/$1/;
    $mimetype = $MTYPES{$suffix};
    $mimetype = $MTYPES{'*'} if (!$mimetype);
    
    if (!$mimetype && -f $mime_types) {
	# okey, this is something special - search the
	# mime.types database
	open ($fh, "<$mime_types");
	while (<$fh>) {
	    if ($_ =~ /^\s*(\S+\/\S+).*\b$suffix\b/) {
		$mimetype = $1;
		last;
	    }
	}
	close ($fh);
    }
    
# okey, didn't find anything useful ..
    if (!($mimetype =~ /\S\/\S/)) {
	$mimetype = "text/plain";
    }
    return $mimetype;
}

###############################
# show Annotation
###############################
sub doAnnotate ($$) {
    my ($rev) = @_;
    my ($pid);
    my ($pathname, $filename);
    my $reader = do {local(*FH);};
    my $writer = do {local(*FH);};

    # make sure the revisions are wellformed, for security
    # reasons ..
    if (!($rev =~ /^[\d\.]+$/)) {
	&fatal("404 Not Found",
		"Malformed query \"$ENV{'QUERY_STRING'}\"");
    }

    if (&forbidden_file($fullname)) {
	&fatal("403 Forbidden", "Access forbidden. This file is mentioned in \@DissallowRead");
	return;
    }

    ($pathname = $where) =~ s/(Attic\/)?[^\/]*$//;
    ($filename = $where) =~ s/^.*\///;

    http_header();

    navigateHeader ($scriptwhere,$pathname,$filename,$rev, "annotate");
    print "<h3 align=center>Annotation of $pathname$filename, Revision $rev</h3>\n";

    # this seems to be necessary
    $| = 1; $| = 0; # Flush

    # this annotate version is based on the
    # cvs annotate-demo Perl script by Cyclic Software
    # It was written by Cyclic Software, http://www.cyclic.com/, and is in
    # the public domain.
    # we could abandon the use of rlog, rcsdiff and co using
    # the cvsserver in a similiar way one day (..after rewrite)
    $pid = open2($reader, $writer, "cvs server") || fatal ("500 Internal Error", 
							       "Fatal Error - unable to open cvs for annotation");
    
    # OK, first send the request to the server.  A simplified example is:
    #     Root /home/kingdon/zwork/cvsroot
    #     Argument foo/xx
    #     Directory foo
    #     /home/kingdon/zwork/cvsroot/foo
    #     Directory .
    #     /home/kingdon/zwork/cvsroot
    #     annotate
    # although as you can see there are a few more details.
    
    print $writer "Root $cvsroot\n";
    print $writer "Valid-responses ok error Valid-requests Checked-in Updated Merged Removed M E\n";
    # Don't worry about sending valid-requests, the server just needs to
    # support "annotate" and if it doesn't, there isn't anything to be done.
    print $writer "UseUnchanged\n";
    print $writer "Argument -r\n";
    print $writer "Argument $rev\n";
    print $writer "Argument $where\n";

    # The protocol requires us to fully fake a working directory (at
    # least to the point of including the directories down to the one
    # containing the file in question).
    # So if $where is "dir/sdir/file", then @dirs will be ("dir","sdir","file")
    my @dirs = split('/', $where);
    my $path = "";
    foreach (@dirs) {
	if ($path eq "") {
	    # In our example, $_ is "dir".
	    $path = $_;
	}
	else {
	    print $writer "Directory $path\n";
	    print $writer "$cvsroot/$path\n";
	    # In our example, $_ is "sdir" and $path becomes "dir/sdir"
	    # And the next time, "file" and "dir/sdir/file" (which then gets
	    # ignored, because we don't need to send Directory for the file).
            $path .= "/$_";
	}
    }
    # And the last "Directory" before "annotate" is the top level.
    print $writer "Directory .\n";
    print $writer "$cvsroot\n";
    
    print $writer "annotate\n";
    # OK, we've sent our command to the server.  Thing to do is to
    # close the writer side and get all the responses.  If "cvs server"
    # were nicer about buffering, then we could just leave it open, I think.
    close ($writer) || die "cannot close: $!";
    
    # Ready to get the responses from the server.
    # For example:
    #     E Annotations for foo/xx
    #     E ***************
    #     M 1.3          (kingdon  06-Sep-97): hello 
    #     ok
    my ($lineNr) = 0;
    my ($oldLrev, $oldLusr) = ("", "");
    my ($revprint, $usrprint);
    if ($annTable) {
	print "<table border=0 cellspacing=0 cellpadding=0>\n";
    }
    else {
	print "<pre>";
    }
    while (<$reader>) {
	my @words = split;
	# Adding one is for the (single) space which follows $words[0].
	my $rest = substr ($_, length ($words[0]) + 1);
	if ($words[0] eq "E") {
	    next;
	}
	elsif ($words[0] eq "M") {
	    $lineNr++;
	    my $lrev = substr ($_, 2, 13);
	    my $lusr = substr ($_, 16,  9);
	    my $line = substr ($_, 36);
	    # we should parse the date here ..
	    if ($lrev eq $oldLrev) {
		$revprint = "             ";
	    }
	    else {
		$revprint = $lrev; $oldLusr = "";
	    }
	    if ($lusr eq $oldLusr) {
		$usrprint = "         ";
	    }
	    else {
		$usrprint = $lusr;
	    }
	    $oldLrev = $lrev;
	    $oldLusr = $lusr;
	    # is there a less timeconsuming way to strip spaces ?
	    ($lrev = $lrev) =~ s/\s+//g;
	    my $isCurrentRev = ("$rev" eq "$lrev");
	    
	    print "<b>" if ($isCurrentRev);
	    printf ("%8s%s%8s %4d:", $revprint, ($isCurrentRev ? "|" : " "), $usrprint, $lineNr);
	    print spacedHtmlText($line);
	    print "</b>" if ($isCurrentRev);
	}
	elsif ($words[0] eq "ok") {
	    # We could complain about any text received after this, like the
	    # CVS command line client.  But for simplicity, we don't.
	}
	elsif ($words[0] eq "error") {
	    fatal ("500 Internal Error", "Error occured during annotate: <b>$_</b>");
	}
    }
    if ($annTable) {
	print "</table>";
    }
    else {
	print "</pre>";
    }
    close ($reader) || warn "cannot close: $!";
    wait;
}

###############################
# make Checkout
###############################
sub doCheckout($$) {
    my ($fullname, $rev) = @_;
    my ($mimetype,$revopt);
    my $fh = do {local(*FH);};

    if ($rev eq 'HEAD' || $rev eq '.') {
	$rev = undef;
    }

    # make sure the revisions a wellformed, for security
    # reasons ..
    if (defined($rev) && !($rev =~ /^[\d\.]+$/)) {
	&fatal("404 Not Found",
		"Malformed query \"$ENV{'QUERY_STRING'}\"");
    }

    if (&forbidden_file($fullname)) {
	&fatal("403 Forbidden", "Access forbidden. This file is mentioned in \@DissallowRead");
	return;
    }

    # get mimetype
    if (defined($input{"content-type"}) && ($input{"content-type"} =~ /\S\/\S/)) {
	$mimetype = $input{"content-type"}
    }
    else {
	$mimetype = &getMimeTypeFromSuffix($fullname);
    }

    if (defined($rev)) {
	$revopt = "-r$rev";
	if ($use_moddate) {
	    readLog($fullname,$rev);
	    $moddate=$date{$rev};
	}
    }
    else {
	$revopt = "-rHEAD";
	if ($use_moddate) {
	    readLog($fullname);
	    $moddate=$date{$symrev{HEAD}};
	}
    }
    
    ### just for the record:
    ### 'cvs co' seems to have a bug regarding single checkout of
    ### directories/files having spaces in it;
    ### this is an issue that should be resolved on cvs's side
    #
    # Safely for a child process to read from.
    if (! open($fh, "-|")) { # child
      open(STDERR, ">&STDOUT"); # Redirect stderr to stdout
      exec("cvs", "-d", "$cvsroot", "co", "-p", "$revopt", "$where");
    } 
#===================================================================
#Checking out squid/src/ftp.c
#RCS:  /usr/src/CVS/squid/src/ftp.c,v
#VERS: 1.1.1.28.6.2
#***************

    # Parse CVS header
    my ($revision, $filename, $cvsheader);
    $filename = "";
    while(<$fh>) {
	last if (/^\*\*\*\*/);
	$revision = $1 if (/^VERS: (.*)$/);
	if (/^Checking out (.*)$/) {
		$filename = $1;
		$filename =~ s/^\.\/*//;
	}
	$cvsheader .= $_;
    }
    if ($filename ne $where) {
	&fatal("500 Internal Error",
	       "Unexpected output from cvs co: $cvsheader"
	       . "<p><b>Check whether the directory $cvsroot/CVSROOT exists "
	       . "and the script has write-access to the CVSROOT/history "
	       . "file if it exists."
	       . "<br>The script needs to place lock files in the "
	       . "directory the file is in as well.</b>");
    }
    $| = 1;

    if ($mimetype eq "text/x-cvsweb-markup") {
	&cvswebMarkup($fh,$fullname,$revision);
    }
    else {
	http_header($mimetype);
	print <$fh>;
    }
    close($fh);
}

sub cvswebMarkup($$$) {
    my ($filehandle,$fullname,$revision) = @_;
    my ($pathname, $filename);

    ($pathname = $where) =~ s/(Attic\/)?[^\/]*$//;
    ($filename = $where) =~ s/^.*\///;
    my ($fileurl) = urlencode($filename);

    http_header();

    navigateHeader ($scriptwhere, $pathname, $filename, $revision, "view");
    print "<HR noshade>";
    print "<table width=\"100%\"><tr><td bgcolor=\"$markupLogColor\">";
    print "File: ", &clickablePath($where, 1);
    print "&nbsp;";
    &download_link(urlencode($fileurl), $revision, "(download)");
    if (!$defaultTextPlain) {
	print "&nbsp;";
	&download_link(urlencode($fileurl), $revision, "(as text)", 
	       "text/plain");
    }
    print "<BR>\n";
    if ($show_log_in_markup) {
	readLog($fullname); #,$revision);
	printLog($revision,0);
    }
    else {
	print "Version: <B>$revision</B><BR>\n";
	print "Tag: <B>", $input{only_with_tag}, "</b><br>\n" if
	    $input{only_with_tag};
    }
    print "</td></tr></table>";
    my @content = <$filehandle>;
    my $url = download_url($fileurl, $revision, $mimetype);
    print "<HR noshade>";
    if ($mimetype =~ /^image/) {
	print "<IMG SRC=\"$url$barequery\"><BR>";
    }
    elsif ($mimetype =~ m%^application/pdf%) {
    	print "<EMBED SRC=\"$url$barequery\" WIDTH=\"100%\"><BR>";
    }
    else {
	print "<PRE>";
	foreach (@content) {
	    print spacedHtmlText($_);
	}
	print "</PRE>";
    }
}

sub viewable($) {
    my ($mimetype) = @_;

    $mimetype =~ m%^text/% ||
    $mimetype =~ m%^image/% ||
    $mimetype =~ m%^application/pdf% ||
    0;
}

###############################
# Show Colored Diff
###############################
sub doDiff($$$$$$) {
	my($fullname, $r1, $tr1, $r2, $tr2, $f) = @_;
        my $fh = do {local(*FH);};
	my ($rev1, $rev2, $sym1, $sym2, @difftype, $diffname, $f1, $f2);
	
	if (&forbidden_file($fullname)) {
	    &fatal("403 Forbidden", "Access forbidden. This file is mentioned in \@DissallowRead");
	    return;
	}

	if ($r1 =~ /([^:]+)(:(.+))?/) {
	    $rev1 = $1;
	    $sym1 = $3;
	}
	if ($r1 eq 'text') {
	    $rev1 = $tr1;
	    $sym1 = "";
	}
	if ($r2 =~ /([^:]+)(:(.+))?/) {
	    $rev2 = $1;
	    $sym2 = $3;
	}
	if ($r2 eq 'text') {
	    $rev2 = $tr2;
	    $sym2 = "";
	}
	# make sure the revisions a wellformed, for security
	# reasons ..
	if (!($rev1 =~ /^[\d\.]+$/) || !($rev2 =~ /^[\d\.]+$/)) {
	    &fatal("404 Not Found",
		    "Malformed query \"$ENV{'QUERY_STRING'}\"");
	}
#
# rev1 and rev2 are now both numeric revisions.
# Thus we do a DWIM here and swap them if rev1 is after rev2.
# XXX should we warn about the fact that we do this?
	if (&revcmp($rev1,$rev2) > 0) {
	    my ($tmp1, $tmp2) = ($rev1, $sym1);
	    ($rev1, $sym1) = ($rev2, $sym2);
	    ($rev2, $sym2) = ($tmp1, $tmp2);
	}
	my $human_readable = 0;
	if ($f eq 'c') {
	    @difftype = qw{-c};
	    $diffname = "Context diff";
	}
	elsif ($f eq 's') {
	    @difftype = qw{--side-by-side --width=164};
	    $diffname = "Side by Side";
	}
	elsif ($f eq 'H') {
	    $human_readable = 1;
	    @difftype = qw{--unified=15};
	    $diffname = "Long Human readable";
	}
	elsif ($f eq 'h') {
	    @difftype =qw{-u};
	    $human_readable = 1;
	    $diffname = "Human readable";
	}
	elsif ($f eq 'u') {
	    @difftype = qw{-u};
	    $diffname = "Unidiff";
	}
	else {
	    fatal ("400 Bad arguments", "Diff format $f not understood");
	}

	# apply special options
	if ($human_readable) {
	    if ($hr_funout) {
	    	push @difftype, '-p';
	    }
	    if ($hr_ignwhite) {
	    	push @difftype, '-w';
	    }
	    if ($hr_ignkeysubst) {
	    	push @difftype, '-kk';
	    }
	}
	if (! open($fh, "-|")) { # child
		open(STDERR, ">&STDOUT"); # Redirect stderr to stdout
		exec("rcsdiff",@difftype,"-r$rev1","-r$rev2",$fullname);
	}
	if ($human_readable) {
	    http_header();
	    &human_readable_diff($fh, $rev2);
	    gzipclose();
	    exit;
	}
	else {
	    http_header("text/plain");
	}
#
#===================================================================
#RCS file: /home/ncvs/src/sys/netinet/tcp_output.c,v
#retrieving revision 1.16
#retrieving revision 1.17
#diff -c -r1.16 -r1.17
#*** /home/ncvs/src/sys/netinet/tcp_output.c     1995/11/03 22:08:08     1.16
#--- /home/ncvs/src/sys/netinet/tcp_output.c     1995/12/05 17:46:35     1.17
#
# Ideas:
# - nuke the stderr output if it's what we expect it to be
# - Add "no differences found" if the diff command supplied no output.
#
#*** src/sys/netinet/tcp_output.c     1995/11/03 22:08:08     1.16
#--- src/sys/netinet/tcp_output.c     1995/12/05 17:46:35     1.17 RELENG_2_1_0
# (bogus example, but...)
#
	if (grep { $_ eq '-u'} @difftype) {
	    $f1 = '---';
	    $f2 = '\+\+\+';
	}
	else {
	    $f1 = '\*\*\*';
	    $f2 = '---';
	}
	while (<$fh>) {
	    if (m|^$f1 $cvsroot|o) {
		s|$cvsroot/||o;
		if ($sym1) {
		    chop;
		    $_ .= " $sym1\n";
		}
	    }
	    elsif (m|^$f2 $cvsroot|o) {
		s|$cvsroot/||o;
		if ($sym2) {
		    chop;
		    $_ .= " $sym2\n";
		}
	    }
	    print $_;
	}
	close($fh);
}

###############################
# Show Logs ..
###############################
sub getDirLogs($$@) {
    my ($cvsroot,$dirname,@otherFiles) = @_;
    my ($state,$otherFiles,$tag, $file, $date, $branchpoint, $branch, $log);
    my ($rev, $revision, $revwanted, $filename, $head, $author);

    $tag = $input{only_with_tag};

    my ($DirName) = "$cvsroot/$where";
    my (@files, @filetags);
    my $fh = do {local(*FH);};

    push(@files, &safeglob("$DirName/*,v"));
    push(@files, &safeglob("$DirName/Attic/*,v")) if (!$input{'hideattic'});
    foreach $file (@otherFiles) {
	push(@files, "$DirName/$file");
    }

    # just execute rlog if there are any files
    if ($#files < 0) { 
	return;
    }

    if (defined($tag)) {
	#can't use -r<tag> as - is allowed in tagnames, but misinterpreated by rlog..
	if (! open($fh, "-|")) {
		open(STDERR, "> /dev/null"); # rlog may complain; ignore.
		exec($no_rlog ? ( "cvs", "log") : ( "rlog" ) ,@files);
	}
    }
    else {
    	my $kidpid = open($fh, "-|");
	if (! $kidpid) {
		open(STDERR, "> /dev/null"); # rlog may complain; ignore.
		exec($no_rlog ? ( "cvs", "log" ) : ( "rlog" ),"-r",@files);
	}
    }
    $state = "start";
    while (<$fh>) {
	if ($state eq "start") {
	    #Next file. Initialize file variables
	    $rev = undef;
	    $revwanted = undef;
	    $branch = undef;
	    $branchpoint = undef;
	    $filename = undef;
	    $log = undef;
	    $revision = undef;
	    $branch = undef;
	    %symrev = ();
	    @filetags = ();
	    #jump to head state
	    $state = "head";
	}
	print "$state:$_" if ($verbose);
again:
	if ($state eq "head") {
	    #$rcsfile = $1 if (/^RCS file: (.+)$/); #not used (yet)
	    $filename = $1 if (/^Working file: (.+)$/);
	    $head = $1 if (/^head: (.+)$/);
	    $branch = $1 if (/^branch: (.+)$/);
	}
	if ($state eq "head" && /^symbolic names/) {
	    $state = "tags";
	    ($branch = $head) =~ s/\.\d+$// if (!defined($branch)); 
	    $branch =~ s/(\.?)(\d+)$/${1}0.$2/;
	    $symrev{MAIN} = $branch;
	    $symrev{HEAD} = $branch;
	    $alltags{MAIN} = 1;
	    $alltags{HEAD} = 1;
	    push (@filetags, "MAIN", "HEAD");
	    next;
	}
	if ($state eq "tags" &&
			    /^\s+(.+):\s+([\d\.]+)\s+$/) {
	    push (@filetags, $1);
	    $symrev{$1} = $2;
	    $alltags{$1} = 1;
	    next;
	}
	if ($state eq "tags" && /^\S/) {
	    if (defined($tag) && (defined($symrev{$tag}) || $tag eq "HEAD")) {
		$revwanted = $tag eq "HEAD" ? $symrev{"MAIN"} : $symrev{$tag};
		($branch = $revwanted) =~ s/\.0\././;
		($branchpoint = $branch) =~ s/\.?\d+$//;
		$revwanted = undef if ($revwanted ne $branch);
	    }
	    elsif (defined($tag) && $tag ne "HEAD") {
		print "Tag not found, skip this file" if ($verbose);
		$state = "skip";
		next;
	    }
	    foreach my $tagfound (@filetags) {
		$tags{$tagfound} = 1;
	    }
	    $state = "head";
	    goto again;
	}
	if ($state eq "head" && /^----------------------------$/) {
	    $state = "log";
	    $rev = undef;
	    $date = undef;
	    $log = "";
	    # Try to reconstruct the relative filename if RCS spits out a full path
	    $filename =~ s%^\Q$DirName\E/%%;
	    next;
	}
	if ($state eq "log") {
	    if (/^----------------------------$/
		|| /^=============================/) {
		# End of a log entry.
		my $revbranch;
		($revbranch = $rev) =~ s/\.\d+$//;
		print "$filename $rev Wanted: $revwanted "
		    . "Revbranch: $revbranch Branch: $branch "
		    . "Branchpoint: $branchpoint\n" if ($verbose);
		if (!defined($revwanted) && defined($branch)
		    && $branch eq $revbranch || !defined($tag)) {
		    print "File revision $rev found for branch $branch\n"
			if ($verbose);
		    $revwanted = $rev;
		}
		if (defined($revwanted) ? $rev eq $revwanted :
		    defined($branchpoint) ? $rev eq $branchpoint :
		    0 && ($rev eq $head)) { # Don't think head is needed here..
		    print "File info $rev found for $filename\n" if ($verbose);
		    my @finfo = ($rev,$date,$log,$author,$filename);
		    my ($name);
		    ($name = $filename) =~ s%/.*%%;
		    $fileinfo{$name} = [ @finfo ];
		    $state = "done" if (defined($revwanted) && $rev eq $revwanted);
		}
		$rev = undef;
		$date = undef;
		$log = "";
	    }
	    elsif (!defined($date) && m|^date:\s+(\d+)/(\d+)/(\d+)\s+(\d+):(\d+):(\d+);|) {
		my $yr = $1;
		# damn 2-digit year routines :-)
		if ($yr > 100) {
		    $yr -= 1900;
		}
		$date = &Time::Local::timegm($6,$5,$4,$3,$2 - 1,$yr);
		($author) = /author: ([^;]+)/;
		$state = "log";
		$log = '';
		next;
	    }
	    elsif (!defined($rev) && m/^revision (.*)$/) {
		$rev = $1;
		next;
	    }
	    else {
		$log = $log . $_;
	    }
	}
	if (/^===============/) {
	    $state = "start";
	    next;
	}
    }
    if ($. == 0) {
	fatal("500 Internal Error", 
	      "Failed to spawn GNU rlog on <em>'".join(", ", @files)."'</em><p>did you set the <b>\$ENV{PATH}</b> in your configuration file correctly ?");
    }
    close($fh);
}

sub readLog($;$) {
	my($fullname,$revision) = @_;
	my ($symnames, $head, $rev, $br, $brp, $branch, $branchrev);
	my $fh = do {local(*FH);};

	if (defined($revision)) {
	    $revision = "-r$revision";
	}
	else {
	    $revision = "";
	}

	undef %symrev;
	undef %revsym;
	undef @allrevisions;
	undef %date;
	undef %author;
	undef %state;
	undef %difflines;
	undef %log;

	print("Going to rlog '$fullname'\n") if ($verbose);
	if (! open($fh, "-|")) { # child
		if ($revision ne '') {
			exec($no_rlog ? ( "cvs", "log" ) : ( "rlog" ),$revision,$fullname);
		}
		else {
			exec($no_rlog ? ( "cvs", "log" ) : ( "rlog" ),$fullname);
		}
	}
	while (<$fh>) {
	    print if ($verbose);
	    if ($symnames) {
		if (/^\s+([^:]+):\s+([\d\.]+)/) {
		    $symrev{$1} = $2;
		}
		else {
		    $symnames = 0;
		}
	    }
	    elsif (/^head:\s+([\d\.]+)/) {
		$head = $1;
	    }
	    elsif (/^branch:\s+([\d\.]+)/) {
		$curbranch = $1;
	    }
	    elsif (/^symbolic names/) {
		$symnames = 1;
	    }
	    elsif (/^-----/) {
		last;
	    }
	}
	($curbranch = $head) =~ s/\.\d+$// if (!defined($curbranch));

# each log entry is of the form:
# ----------------------------
# revision 3.7.1.1
# date: 1995/11/29 22:15:52;  author: fenner;  state: Exp;  lines: +5 -3
# log info
# ----------------------------
	logentry:
	while (!/^=========/) {
	    $_ = <$fh>;
	    last logentry if (!defined($_));	# EOF
	    print "R:", $_ if ($verbose);
	    if (/^revision ([\d\.]+)/) {
		$rev = $1;
		unshift(@allrevisions,$rev);
	    }
	    elsif (/^========/ || /^----------------------------$/) {
		next logentry;
	    }
	    else {
		# The rlog output is syntactically ambiguous.  We must
		# have guessed wrong about where the end of the last log
		# message was.
		# Since this is likely to happen when people put rlog output
		# in their commit messages, don't even bother keeping
		# these lines since we don't know what revision they go with
		# any more.
		next logentry;
#		&fatal("500 Internal Error","Error parsing RCS output: $_");
	    }
	    $_ = <$fh>;
	    print "D:", $_ if ($verbose);
	    if (m|^date:\s+(\d+)/(\d+)/(\d+)\s+(\d+):(\d+):(\d+);\s+author:\s+(\S+);\s+state:\s+(\S+);\s+(lines:\s+([0-9\s+-]+))?|) {
		my $yr = $1;
                # damn 2-digit year routines :-)
                if ($yr > 100) {
                    $yr -= 1900;
                }
		$date{$rev} = &Time::Local::timegm($6,$5,$4,$3,$2 - 1,$yr);
		$author{$rev} = $7;
		$state{$rev} = $8;
		$difflines{$rev} = $10;
	    }
	    else {
		&fatal("500 Internal Error", "Error parsing RCS output: $_");
	    }
	    line:
	    while (<$fh>) {
		print "L:", $_ if ($verbose);
		next line if (/^branches:\s/);
		last line if (/^----------------------------$/ || /^=========/);
		$log{$rev} .= $_;
	    }
	    print "E:", $_ if ($verbose);
	}
	close($fh);
	print "Done reading RCS file\n" if ($verbose);

	@revorder = reverse sort {revcmp($a,$b)} @allrevisions;
	print "Done sorting revisions",join(" ",@revorder),"\n" if ($verbose);

#
# HEAD is an artificial tag which is simply the highest tag number on the main
# branch, unless there is a branch tag in the RCS file in which case it's the
# highest revision on that branch.  Find it by looking through @revorder; it
# is the first commit listed on the appropriate branch.
# This is not neccesary the same revision as marked as head in the RCS file.
	my $headrev = $curbranch || "1";
	($symrev{"MAIN"} = $headrev) =~ s/(\.?)(\d+)$/${1}0.$2/;
	revision:
	foreach $rev (@revorder) {
	    if ($rev =~ /^(\S*)\.\d+$/ && $headrev eq $1) {
		$symrev{"HEAD"} = $rev;
		last revision;
	    }
	}
	($symrev{"HEAD"} = $headrev) =~ s/\.\d+$//
            if (!defined($symrev{"HEAD"}));
	print "Done finding HEAD\n" if ($verbose);
#
# Now that we know all of the revision numbers, we can associate
# absolute revision numbers with all of the symbolic names, and
# pass them to the form so that the same association doesn't have
# to be built then.
#
	undef @branchnames;
	undef %branchpoint;
	undef $sel;

	foreach (reverse sort keys %symrev) {
	    $rev = $symrev{$_};
	    if ($rev =~ /^((.*)\.)0\.(\d+)$/) {
		push(@branchnames, $_);
		#
		# A revision number of A.B.0.D really translates into
		# "the highest current revision on branch A.B.D".
		#
		# If there is no branch A.B.D, then it translates into
		# the head A.B .
		#
		# This reasoning also applies to the main branch A.B,
		# with the branch number 0.A, with the exception that
		# it has no head to translate to if there is nothing on
		# the branch, but I guess this can never happen?
		#
		# Since some stupid people actually import/check in
		# files with version 0.X we assume that the above cannot
		# happen, and regard 0.X(.*) as a revision and not a branch.
		#
		$head = defined($2) ? $2 : "";
		$branch = $3;
		$branchrev = $head . ($head ne "" ? "." : "") . $branch;
		my $regex;
		($regex = $branchrev) =~ s/\./\\./g;
		$rev = $head;

		revision:
		foreach my $r (@revorder) {
		    if ($r =~ /^${regex}\b/) {
			$rev = $branchrev;
			last revision;
		    }
		}
		next if ($rev eq "");
		if ($rev ne $head && $head ne "") {
		    $branchpoint{$head} .= ", " if ($branchpoint{$head});
		    $branchpoint{$head} .= $_;
		}
	    }
	    $revsym{$rev} .= ", " if ($revsym{$rev});
	    $revsym{$rev} .= $_;
	    $sel .= "<OPTION VALUE=\"${rev}:${_}\">$_</OPTION>\n";
	}
	print "Done associating revisions with branches\n" if ($verbose);

	my ($onlyonbranch, $onlybranchpoint);
	if ($onlyonbranch = $input{'only_with_tag'}) {
	    $onlyonbranch = $symrev{$onlyonbranch};
	    if ($onlyonbranch =~ s/\.0\././) {
		($onlybranchpoint = $onlyonbranch) =~ s/\.\d+$//;
	    }
            else {
		$onlybranchpoint = $onlyonbranch;
	    }
	    if (!defined($onlyonbranch) || $onlybranchpoint eq "") {
		fatal("404 Tag not found","Tag $input{'only_with_tag'} not defined");
	    }
	}

	undef @revisions;

	foreach (@allrevisions) {
	    ($br = $_) =~ s/\.\d+$//;
	    ($brp = $br) =~ s/\.\d+$//;
	    next if ($onlyonbranch && $br ne $onlyonbranch &&
					$_ ne $onlybranchpoint);
	    unshift(@revisions,$_);
	}

	if ($logsort eq "date") {
	    # Sort the revisions in commit order an secondary sort on revision
	    # (secondary sort needed for imported sources, or the first main
	    # revision gets before the same revision on the 1.1.1 branch)
	    @revdisplayorder = sort {$date{$b} <=> $date{$a} || -revcmp($a, $b)} @revisions;
	}
        elsif ($logsort eq "rev") {
	    # Sort the revisions in revision order, highest first
	    @revdisplayorder = reverse sort {revcmp($a,$b)} @revisions;
	}
        else {
	    # No sorting. Present in the same order as rlog / cvs log
	    @revdisplayorder = @revisions;
	}

}

sub printLog($;$) {
	my ($link, $br, $brp);
	($_,$link) = @_;
	($br = $_) =~ s/\.\d+$//;
	($brp = $br) =~ s/\.?\d+$//;
	my ($isDead, $prev);

	$link = 1 if (!defined($link));
	$isDead = ($state{$_} eq "dead");

	if ($link && !$isDead) {
	    my ($filename);
	    ($filename = $where) =~ s/^.*\///;
	    my ($fileurl) = urlencode($filename);
	    print "<a NAME=\"rev$_\"></a>";
	    if (defined($revsym{$_})) {
		foreach my $sym (split(", ", $revsym{$_})) {
		    print "<a NAME=\"$sym\"></a>";
		}
	    }
	    if (defined($revsym{$br}) && $revsym{$br} && !defined($nameprinted{$br})) {
		foreach my $sym (split(", ", $revsym{$br})) {
		    print "<a NAME=\"$sym\"></a>";
		}
		$nameprinted{$br} = 1;
	    }
	    print "\n Revision ";
	    &download_link($fileurl, $_, $_,
		$defaultViewable ? "text/x-cvsweb-markup" : undef);
	    if ($defaultViewable) {
		print " / ";
		&download_link($fileurl, $_, "(download)", $mimetype);
	    }
	    if (not $defaultTextPlain) {
		print " / ";
		&download_link($fileurl, $_, "(as text)", 
			   "text/plain");
	    }
	    if (!$defaultViewable) {
		print " / ";
		&download_link($fileurl, $_, "(view)", "text/x-cvsweb-markup");
	    }
	    if ($allow_annotate) {
		print " - <a href=\"" . $scriptname . "/" . urlencode($where) . "?annotate=$_$barequery\">";
		print "annotate</a>";
	    }
	    # Plus a select link if enabled, and this version isn't selected
	    if ($allow_version_select) {
		if ((!defined($input{"r1"}) || $input{"r1"} ne $_)) {
		    print " - <A HREF=\"${scriptwhere}?r1=$_$barequery" .
			"\">[select for diffs]</A>\n";
		}
		else {
		    print " - <b>[selected]</b>";
		}
	    }
	}
	else {
	    print "Revision <B>$_</B>";
	}
	if (/^1\.1\.1\.\d+$/) {
	    print " <i>(vendor branch)</i>";
	}
	if (defined @mytz) {
	    my ($est) = $mytz[(localtime($date{$_}))[8]];
	    print ", <i>" . scalar localtime($date{$_}) . " $est</i> (";
	} else {
	    print ", <i>" . scalar gmtime($date{$_}) . " UTC</i> (";
	}
	print readableTime(time() - $date{$_},1) . " ago)";
	print " by ";
	print "<i>" . $author{$_} . "</i>\n";
	print "<BR>Branch: <b>",$link?link_tags($revsym{$br}):$revsym{$br},"</b>\n"
	    if ($revsym{$br});
	print "<BR>CVS Tags: <b>",$link?link_tags($revsym{$_}):$revsym{$_},"</b>"
	    if ($revsym{$_});
	print "<BR>Branch point for: <b>",$link?link_tags($branchpoint{$_}):$branchpoint{$_},"</b>\n"
	    if ($branchpoint{$_});
	# Find the previous revision
	my @prevrev = split(/\./, $_);
	do {
	    if (--$prevrev[$#prevrev] <= 0) {
		# If it was X.Y.Z.1, just make it X.Y
		pop(@prevrev);
		pop(@prevrev);
	    }
	    $prev = join(".", @prevrev);
	} until (defined($date{$prev}) || $prev eq "");
	if ($prev ne "") {
	    if ($difflines{$_}) {
		print "<BR>Changes since <b>$prev: $difflines{$_} lines</b>";
	    }
	}
	if ($isDead) {
	    print "<BR><B><I>FILE REMOVED</I></B>\n";
	}
	elsif ($link) {
	    my %diffrev = ();
	    $diffrev{$_} = 1;
	    $diffrev{""} = 1;
	    print "<BR>Diff";
	    #
	    # Offer diff to previous revision
	    if ($prev) {
		$diffrev{$prev} = 1;
		print " to previous <A HREF=\"${scriptwhere}.diff?r1=$prev";
		print "&amp;r2=$_" . $barequery . "\">$prev</A>\n";
		if (!$hr_default) { # offer a human readable version if not default
		    print "(<A HREF=\"${scriptwhere}.diff?r1=$prev";
		    print "&amp;r2=$_" . $barequery . "&amp;f=h\">colored</A>)\n";
		}
	    }
	    #
	    # Plus, if it's on a branch, and it's not a vendor branch,
	    # offer a diff with the branch point.
	    if ($revsym{$brp} && !/^1\.1\.1\.\d+$/ && !defined($diffrev{$brp})) {
		print " to branchpoint <A HREF=\"${scriptwhere}.diff?r1=$brp";
		print "&amp;r2=$_" . $barequery . "\">$brp</A>\n";
		if (!$hr_default) { # offer a human readable version if not default
		print "(<A HREF=\"${scriptwhere}.diff?r1=$brp";
		print "&amp;r2=$_" . $barequery . "&amp;f=h\">colored</A>)\n";
		}
	    }
	    #
	    # Plus, if it's on a branch, and it's not a vendor branch,
	    # offer to diff with the next revision of the higher branch.
	    # (e.g. change gets committed and then brought
	    # over to -stable)
	    if (/^\d+\.\d+\.\d+/ && !/^1\.1\.1\.\d+$/) {
		my ($i,$nextmain);
		for ($i = 0; $i < $#revorder && $revorder[$i] ne $_; $i++){}
		my (@tmp2) = split(/\./, $_);
		for ($nextmain = ""; $i > 0; $i--) {
		    my ($next) = $revorder[$i-1];
		    my (@tmp1) = split(/\./, $next);
		    if ($#tmp1 < $#tmp2) {
			$nextmain = $next;
			last;
		    }
		    # Only the highest version on a branch should have
		    # a diff for the "next main".
		    last if ($#tmp1 == $#tmp2 && join(".",@tmp1[0..$#tmp1-1])
			     eq join(".",@tmp2[0..$#tmp1-1]));
		}
		if (!defined($diffrev{$nextmain})) {
		    $diffrev{$nextmain} = 1;
		    print " next main <A HREF=\"${scriptwhere}.diff?r1=$nextmain";
		    print "&amp;r2=$_" . $barequery .
			"\">$nextmain</A>\n";
		    if (!$hr_default) { # offer a human readable version if not default
			print "(<A HREF=\"${scriptwhere}.diff?r1=$nextmain";
			print "&amp;r2=$_" . $barequery .
			    "&amp;f=h\">colored</A>)\n";
		    }
		}
	    }
	    # Plus if user has selected only r1, then present a link
	    # to make a diff to that revision
	    if (defined($input{"r1"}) && !defined($diffrev{$input{"r1"}})) {
		$diffrev{$input{"r1"}} = 1;
		print " to selected <A HREF=\"${scriptwhere}.diff?"
			. "r1=$input{'r1'}&amp;r2=$_" . $barequery
			. "\">$input{'r1'}</A>\n";
		if (!$hr_default) { # offer a human readable version if not default
		    print "(<A HREF=\"${scriptwhere}.diff?r1=$input{'r1'}";
		    print "&amp;r2=$_" . $barequery .
			"&amp;f=h\">colored</A>)\n";

		}
	    }
	}
	print "<PRE>\n";
	print &htmlify($log{$_});
	print "</PRE>\n";
}

sub doLog($) {
	my($fullname) = @_;
	my ($diffrev, $upwhere, $filename, $backurl);
	
	readLog($fullname);

        html_header("CVS log for $where");
	($upwhere = $where) =~ s|(Attic/)?[^/]+$||;
        ($filename = $where) =~ s|^.*/||;
        $backurl = $scriptname . "/" . urlencode($upwhere) . $query;
	print &link($backicon, "$backurl#$filename"),
              " <b>Up to ", &clickablePath($upwhere, 1), "</b><p>\n";
	print "<A HREF=\"#diff\">Request diff between arbitrary revisions</A>\n";
	print "<HR NOSHADE>\n";
	if ($curbranch) {
	    print "Default branch: ";
	    print ($revsym{$curbranch} || $curbranch);
	}
	else {
	    print "No default branch";
	}
	print "<BR>\n";
	if ($input{only_with_tag}) {
	    print "Current tag: $input{only_with_tag}<BR>\n";
	}

	undef %nameprinted;

	for (my $i = 0; $i <= $#revdisplayorder; $i++) {
	    print "<HR size=1 NOSHADE>";
	    printLog($revdisplayorder[$i]);
	}

        print "<HR NOSHADE>";
	print "<A NAME=diff>\n";
	print "This form allows you to request diff's between any two\n";
	print "revisions of a file.  You may select a symbolic revision\n";
	print "name using the selection box or you may type in a numeric\n";
	print "name using the type-in text box.\n";
	print "</A><P>\n";
	print "<FORM METHOD=\"GET\" ACTION=\"${scriptwhere}.diff\" NAME=\"diff_select\">\n";
        foreach (@stickyvars) {
	    print "<INPUT TYPE=HIDDEN NAME=\"$_\" VALUE=\"$input{$_}\">\n"
		if (defined($input{$_})
		    && ((!defined($DEFAULTVALUE{$_})
		         || $input{$_} ne $DEFAULTVALUE{$_})
		        && $input{$_} ne ""));
	}
	print "Diffs between \n";
	print "<SELECT NAME=\"r1\">\n";
	print "<OPTION VALUE=\"text\" SELECTED>Use Text Field</OPTION>\n";
	print $sel;
	print "</SELECT>\n";
	$diffrev = $revdisplayorder[$#revdisplayorder];
	$diffrev = $input{"r1"} if (defined($input{"r1"}));
	print "<INPUT TYPE=\"TEXT\" SIZE=\"$inputTextSize\" NAME=\"tr1\" VALUE=\"$diffrev\" onChange='document.diff_select.r1.selectedIndex=0'>\n";
	print " and \n";
	print "<SELECT NAME=\"r2\">\n";
	print "<OPTION VALUE=\"text\" SELECTED>Use Text Field</OPTION>\n";
	print $sel;
	print "</SELECT>\n";
	$diffrev = $revdisplayorder[0];
	$diffrev = $input{"r2"} if (defined($input{"r2"}));
	print "<INPUT TYPE=\"TEXT\" SIZE=\"$inputTextSize\" NAME=\"tr2\" VALUE=\"$diffrev\" onChange='document.diff_select.r2.selectedIndex=0'>\n";
        print "<BR>Type of Diff should be a&nbsp;";
	printDiffSelect(0);
	print "<INPUT TYPE=SUBMIT VALUE=\"  Get Diffs  \">\n";
	print "</FORM>\n";
	print "<HR noshade>\n";
        if (@branchnames) {
	    print "<A name=branch></A>\n";
	    print "<FORM METHOD=\"GET\" ACTION=\"$scriptwhere\">\n";
	    foreach (@stickyvars) {
		next if ($_ eq "only_with_tag");
		next if ($_ eq "logsort");
		print "<INPUT TYPE=HIDDEN NAME=\"$_\" VALUE=\"$input{$_}\">\n"
		    if (defined($input{$_})
		        && (!defined($DEFAULTVALUE{$_})
			    || $input{$_} ne $DEFAULTVALUE{$_})
			&& $input{$_} ne "");
	    }
	    print "View only Branch: \n";
	    print "<SELECT NAME=\"only_with_tag\"";
	    print " onchange=\"submit()\"" if ($use_java_script);
	    print ">\n";
	    print "<OPTION VALUE=\"\"";
	    print " SELECTED" if (defined($input{"only_with_tag"}) &&
		$input{"only_with_tag"} eq "");
	    print ">Show all branches</OPTION>\n";
	    foreach (reverse sort @branchnames) {
		print "<OPTION";
		print " SELECTED" if (defined($input{"only_with_tag"})
			&& $input{"only_with_tag"} eq $_);
		print ">${_}</OPTION>\n";
	    }
	    print "</SELECT>\n";
	    print "<INPUT TYPE=SUBMIT VALUE=\"  View Branch  \">\n";
	    print "</FORM>\n";
	}
	print "<A name=logsort></A>\n";
	print "<FORM METHOD=\"GET\" ACTION=\"$scriptwhere\">\n";
	foreach (@stickyvars) {
	    next if ($_ eq "only_with_tag");
	    next if ($_ eq "logsort");
	    print "<INPUT TYPE=HIDDEN NAME=\"$_\" VALUE=\"$input{$_}\">\n"
		if (defined($input{$_})
		    && (!defined($DEFAULTVALUE{$_})
		        || $input{$_} ne $DEFAULTVALUE{$_})
		    && $input{$_} ne "");
	}
	print "Sort log by: \n";
	print "<SELECT NAME=\"logsort\"";
	print " onchange=\"submit()\"" if ($use_java_script);
	print ">\n";
	print "<OPTION VALUE=cvs",$logsort eq "cvs" ? " SELECTED" : "", ">Not sorted</OPTION>";
	print "<OPTION VALUE=date",$logsort eq "date" ? " SELECTED" : "", ">Commit date</OPTION>";
	print "<OPTION VALUE=rev",$logsort eq "rev" ? " SELECTED" : "", ">Revision</OPTION>";
	print "</SELECT>\n";
	print "<INPUT TYPE=SUBMIT VALUE=\"  Sort  \">\n";
	print "</FORM>\n";
        print &html_footer;
	print "</BODY></HTML>\n";
}

sub flush_diff_rows ($$$$)
{
    my $j;
    my ($leftColRef,$rightColRef,$leftRow,$rightRow) = @_;

    if (!defined($state)) {
	return;
    }

    if ($state eq "PreChangeRemove") {          # we just got remove-lines before
      for ($j = 0 ; $j < $leftRow; $j++) {
          print  "<tr><td bgcolor=\"$diffcolorRemove\">@$leftColRef[$j]</td>";
          print  "<td bgcolor=\"$diffcolorEmpty\">&nbsp;</td></tr>\n";
      }
    }
    elsif ($state eq "PreChange") {             # state eq "PreChange"
      # we got removes with subsequent adds
      for ($j = 0; $j < $leftRow || $j < $rightRow ; $j++) {  # dump out both cols
          print  "<tr>";
          if ($j < $leftRow) {
	      print  "<td bgcolor=\"$diffcolorChange\">@$leftColRef[$j]</td>";
	  }
          else {
	      print  "<td bgcolor=\"$diffcolorDarkChange\">&nbsp;</td>";
	  }
          if ($j < $rightRow) {
	      print  "<td bgcolor=\"$diffcolorChange\">@$rightColRef[$j]</td>";
	  }
          else {
	      print  "<td bgcolor=\"$diffcolorDarkChange\">&nbsp;</td>";
	  }
          print  "</tr>\n";
      }
    }
}

##
# Function to generate Human readable diff-files
# human_readable_diff(String revision_to_return_to);
##
sub human_readable_diff($){
  my ($i,$difftxt, $where_nd, $filename, $pathname, $scriptwhere_nd);
  my ($fh, $rev) = @_;
  my ($date1, $date2, $r1d, $r2d, $r1r, $r2r, $rev1, $rev2, $sym1, $sym2);
  my (@rightCol, @leftCol);

  ($where_nd = $where) =~ s/.diff$//;
  ($filename = $where_nd) =~ s/^.*\///;
  ($pathname = $where_nd) =~ s/(Attic\/)?[^\/]*$//;
  ($scriptwhere_nd = $scriptwhere) =~ s/.diff$//;

  navigateHeader ($scriptwhere_nd, $pathname, $filename, $rev, "diff");

  # Read header to pick up read revision and date, if possible
  while (<$fh>) {
      ($r1d,$r1r) = /\t(.*)\t(.*)$/ if (/^--- /);
      ($r2d,$r2r) = /\t(.*)\t(.*)$/ if (/^\+\+\+ /);
      last if (/^\+\+\+ /);
  }
  if (defined($r1r) && $r1r =~ /^(\d+\.)+\d+$/) {
    $rev1 = $r1r;
    $date1 = $r1d;
  }
  if (defined($r2r) && $r2r =~ /^(\d+\.)+\d+$/) {
    $rev2 = $r2r;
    $date2 = $r2d;
  }
  
  print "<h3 align=center>Diff for /$where_nd between version $rev1 and $rev2</h3>\n";

  print "<table border=0 cellspacing=0 cellpadding=0 width=\"100%\">\n";
  print "<tr bgcolor=\"#ffffff\">\n";
  print "<th width=\"50%\" valign=TOP>";
  print "version $rev1";
  print ", $date1" if (defined($date1));
  print "<br>Tag: $sym1\n" if ($sym1);
  print "</th>\n";
  print "<th width=\"50%\" valign=TOP>";
  print "version $rev2";
  print ", $date2" if (defined($date2));
  print "<br>Tag: $sym2\n" if ($sym1);
  print "</th>\n";

  my $fs = "<font face=\"$difffontface\" size=\"$difffontsize\">";
  my $fe = "</font>";

  my $leftRow = 0;
  my $rightRow = 0;
  my ($oldline, $newline, $funname, $diffcode, $rest);

  # Process diff text
  # The diffrows are could make excellent use of
  # cascading style sheets because we've to set the
  # font and color for each row. anyone ...?
  ####
  while (<$fh>) {
      $difftxt = $_;
      
      if ($difftxt =~ /^@@/) {
	  ($oldline,$newline,$funname) = $difftxt =~ /@@ \-([0-9]+).*\+([0-9]+).*@@(.*)/;
          print  "<tr bgcolor=\"$diffcolorHeading\"><td width=\"50%\">";
	  print  "<table width=\"100%\" border=1 cellpadding=5><tr><td><b>Line $oldline</b>";
	  print  "&nbsp;<font size=-1>$funname</font></td></tr></table>";
          print  "</td><td width=\"50%\">";
	  print  "<table width=\"100%\" border=1 cellpadding=5><tr><td><b>Line $newline</b>";
	  print  "&nbsp;<font size=-1>$funname</font></td></tr></table>";
	  print  "</td>\n";
	  $state = "dump";
	  $leftRow = 0;
	  $rightRow = 0;
      }
      else {
	  ($diffcode,$rest) = $difftxt =~ /^([-+ ])(.*)/;
	  $_ = spacedHtmlText ($rest);

	  # Add fontface, size
	  $_ = "$fs&nbsp;$_$fe";
	  
	  #########
	  # little state machine to parse unified-diff output (Hen, zeller@think.de)
	  # in order to get some nice 'ediff'-mode output
	  # states:
	  #  "dump"             - just dump the value
	  #  "PreChangeRemove"  - we began with '-' .. so this could be the start of a 'change' area or just remove
	  #  "PreChange"        - okey, we got several '-' lines and moved to '+' lines -> this is a change block
	  ##########

	  if ($diffcode eq '+') {
	      if ($state eq "dump") {  # 'change' never begins with '+': just dump out value
		  print  "<tr><td bgcolor=\"$diffcolorEmpty\">&nbsp;</td><td bgcolor=\"$diffcolorAdd\">$_</td></tr>\n";
	      }
	      else {                   # we got minus before
		  $state = "PreChange";
		  $rightCol[$rightRow++] = $_;
	      }
	  } 
	  elsif ($diffcode eq '-') {
	      $state = "PreChangeRemove";
	      $leftCol[$leftRow++] = $_;
        }
        else {  # empty diffcode
            flush_diff_rows \@leftCol, \@rightCol, $leftRow, $rightRow;
	      print  "<tr><td>$_</td><td>$_</td></tr>\n";
	      $state = "dump";
	      $leftRow = 0;
	      $rightRow = 0;
	  }
      }
  }
  flush_diff_rows \@leftCol, \@rightCol, $leftRow, $rightRow;

  # state is empty if we didn't have any change
  if (!$state) {
      print "<tr><td colspan=2>&nbsp;</td></tr>";
      print "<tr bgcolor=\"$diffcolorEmpty\" >";
      print "<td colspan=2 align=center><b>- No viewable Change -</b></td></tr>";
  }
  print  "</table>";
  close($fh);

  print "<br><hr noshade width=\"100%\">\n";

  print "<table border=0>";

  print "<tr><td>";
  # print legend
  print "<table border=1><tr><td>";
  print  "Legend:<br><table border=0 cellspacing=0 cellpadding=1>\n";
  print  "<tr><td align=center bgcolor=\"$diffcolorRemove\">Removed from v.$rev1</td><td bgcolor=\"$diffcolorEmpty\">&nbsp;</td></tr>";
  print  "<tr bgcolor=\"$diffcolorChange\"><td align=center colspan=2>changed lines</td></tr>";
  print  "<tr><td bgcolor=\"$diffcolorEmpty\">&nbsp;</td><td align=center bgcolor=\"$diffcolorAdd\">Added in v.$rev2</td></tr>";
  print  "</table></td></tr></table>\n";

  print "<td>";
  # Print format selector
  print "<FORM METHOD=\"GET\" ACTION=\"${scriptwhere}\">\n";
  foreach my $var (keys %input) {
    next if ($var eq "f");
    next if (defined($DEFAULTVALUE{$var})
	     && $DEFAULTVALUE{$var} eq $input{$var});
    print "<INPUT TYPE=HIDDEN NAME=\"",urlencode($var),"\" VALUE=\"",
	    urlencode($input{$var}),"\">\n";
  }
  printDiffSelect($use_java_script);
  print "<INPUT TYPE=SUBMIT VALUE=\"Show\">\n";
  print "</FORM>\n";
  print "</td>";

  print "</tr></table>";
}

sub navigateHeader ($$$$$) {
    my ($swhere,$path,$filename,$rev,$title) = @_;
    $swhere = "" if ($swhere eq $scriptwhere);
    $swhere = urlencode($filename) if ($swhere eq "");
    print "<\!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\">";
    print "<HTML>\n<HEAD>\n";
    local $charset = $config{'cvsenc'} || &get_charset();
    if ($charset) {
	print "<meta http-equiv=\"Content-Type\" content=\"text/html; Charset=$charset\">\n";
	}
    print '<!-- hennerik CVSweb $Revision: 1.112 $ -->';
    print "\n<TITLE>$path$filename - $title - $rev</TITLE></HEAD>\n";
    print  "<BODY BGCOLOR=\"$backcolor\">\n";
    print "<table width=\"100%\" border=0 cellspacing=0 cellpadding=1 bgcolor=\"$navigationHeaderColor\">";
    print "<tr valign=bottom><td>";
    print  "<a href=\"$swhere$query#rev$rev\">$backicon";
    print "</a> <b>Return to ", &link("$filename","$swhere$query#rev$rev")," CVS log";
    print "</b> $fileicon</td>";
    
    print "<td align=right>$diricon <b>Up to ", &clickablePath($path, 1), "</b></td>";
    print "</tr></table>";
}

sub plural_write ($$)
{
    my ($num,$text) = @_;
    if ($num != 1) {
	$text = $text . "s";
    }
    if ($num > 0) {
	return $num . " " . $text;
    }
    else {
	return "";
    }
}

##
# print readable timestamp in terms of
# '..time ago'
# H. Zeller <zeller@think.de>
##
sub readableTime($$) {
    my ($i, $break, $retval);
    my ($secs,$long) = @_;

    # this function works correct for time >= 2 seconds
    if ($secs < 2) {
	return "very little time";
    }

    my %desc = (1 , 'second',
		   60, 'minute',
		   3600, 'hour',
		   86400, 'day',
		   604800, 'week',
		   2628000, 'month',
		   31536000, 'year');
    my @breaks = sort {$a <=> $b} keys %desc;
    $i = 0;
    while ($i <= $#breaks && $secs >= 2 * $breaks[$i]) { 
	$i++;
    }
    $i--;
    $break = $breaks[$i];
    $retval = plural_write(int ($secs / $break), $desc{"$break"});

    if ($long == 1 && $i > 0) {
	my $rest = $secs % $break;
	$i--;
	$break = $breaks[$i];
	my $resttime = plural_write(int ($rest / $break), 
				$desc{"$break"});
	if ($resttime) {
	    $retval = $retval . ", " . $resttime;
	}
    }

    return $retval;
}

##
# clickablePath(String pathname, boolean last_item_clickable)
#
# returns a html-ified path whereas each directory is a link for
# faster navigation. last_item_clickable controls whether the
# basename (last directory/file) is a link as well
##
sub clickablePath($$) {
    my ($pathname,$clickLast) = @_;    
    my $retval = '';
    
    if ($pathname eq '/') {
	# this should never happen - chooseCVSRoot() is
	# intended to do this
	$retval = "[$cvstree]";
    }
    else {
	$retval = $retval . " <a href=\"${scriptname}/${query}#dirlist\">[$cvstree]</a>";
	my $wherepath = '';
	my ($lastslash) = $pathname =~ m|/$|;
	foreach (split(/\//, $pathname)) {
	    $retval = $retval . " / ";
	    $wherepath = $wherepath . '/' . $_;
	    my ($last) = "$wherepath/" eq "/$pathname"
		|| "$wherepath" eq "/$pathname";
	    if ($clickLast || !$last) {
		$retval = $retval . "<a href=\"${scriptname}"
		    . urlencode($wherepath)
		    . (!$last || $lastslash ? '/' : '')
		    . ${query}
	            . (!$last || $lastslash ? "#dirlist" : "")
		    . "\">$_</a>";
	    }
	    else { # do not make a link to the current dir
		$retval = $retval .  $_;
	    }
	}
    }
    return $retval;
}

sub chooseCVSRoot() {
    my @foo;
    foreach (sort keys %CVSROOT) {
	if (-d $CVSROOT{$_}) {
	    push(@foo, $_);
	}
    }
    if (@foo > 1) {
	my ($k);
	print "<form method=\"GET\" action=\"${scriptwhere}\">\n";
	foreach $k (keys %input) {
	    print "<input type=hidden NAME=$k VALUE=$input{$k}>\n" 
		if ($input{$k}) && ($k ne "cvsroot");
	}
	# Form-Elements look wierd in Netscape if the background
	# isn't gray and the form elements are not placed
	# within a table ...
	print "<table><tr>";
	print "<td>CVS Root:</td>";
	print "<td>\n<select name=\"cvsroot\"";
	print " onchange=\"submit()\"" if ($use_java_script);
	print ">\n";
	foreach $k (@foo) {
	    print "<option value=\"$k\"";
	    print " selected" if ("$k" eq "$cvstree");
	    print ">" . ($CVSROOTdescr{"$k"} ? $CVSROOTdescr{"$k"} :
	    		$k). "</option>\n";
	}
	print "</select>\n</td>";
	print "<td><input type=submit value=\"Go\"></td>";
	print "</tr></table></form>";
    }
    else {
	# no choice ..
	print "CVS Root: <b>[$cvstree]</b>";
    }
}

sub chooseMirror() {
    my ($mirror,$moremirrors);
    $moremirrors = 0;
    # This code comes from the original BSD-cvsweb
    # and may not be useful for your site; If you don't
    # set %MIRRORS this won't show up, anyway
    #
    # Should perhaps exlude the current site somehow.. 
    if (keys %MIRRORS) {
	print "\nThis cvsweb is mirrored in:\n";
	foreach $mirror (keys %MIRRORS) {
	    print ", " if ($moremirrors);
	    print qq(<a href="$MIRRORS{$mirror}">$mirror</A>\n);
	    $moremirrors = 1;
	}
	print "<p>\n";
    }
}

sub fileSortCmp() {
    my ($comp) = 0;
    my ($c,$d,$af,$bf);

    ($af = $a) =~ s/,v$//;
    ($bf = $b) =~ s/,v$//;
    my ($rev1,$date1,$log1,$author1,$filename1) = @{$fileinfo{$af}}
        if (defined($fileinfo{$af}));
    my ($rev2,$date2,$log2,$author2,$filename2) = @{$fileinfo{$bf}}
        if (defined($fileinfo{$bf}));

    if (defined($filename1) && defined($filename2) && $af eq $filename1 && $bf eq $filename2) {
	# Two files
	$comp = -revcmp($rev1, $rev2) if ($byrev && $rev1 && $rev2);
	$comp = ($date2 <=> $date1) if ($bydate && $date1 && $date2);
	$comp = ($log1 cmp $log2) if ($bylog && $log1 && $log2);
	$comp = ($author1 cmp $author2) if ($byauthor && $author1 && $author2);
    }
    if ($comp == 0) {
	# Directories first, then sorted on name if no other sort critera
	# available.
	my $ad = ((-d "$fullname/$a")?"D":"F");
	my $bd = ((-d "$fullname/$b")?"D":"F");
	($c=$a) =~ s|.*/||;
	($d=$b) =~ s|.*/||;
	$comp = ("$ad$c" cmp "$bd$d");
    }
    return $comp;
}

# make A url for downloading
sub download_url($$$) {
    my ($url,$revision,$mimetype) = @_;

    $revision =~ s/\.0\././;

    if (defined($checkout_magic)
	&& (!defined($mimetype) || $mimetype ne "text/x-cvsweb-markup")) {
	my ($path);
	($path = $where) =~ s|/[^/]*$|/|;
	$url = "$scriptname/$checkoutMagic/${path}$url";
    }
    $url .= "?rev=$revision";
    $url .= "&amp;content-type=$mimetype" if (defined($mimetype));

    return $url;
}

# Presents a link to download the 
# selected revision
sub download_link($$$$) {
    my ($url,$revision,$textlink,$mimetype) = @_;
    my ($fullurl) = download_url($url,$revision,$mimetype);
    my ($paren) = $textlink =~ /^\(/;
    $textlink =~ s/^\(// if ($paren);
    $textlink =~ s/\)$// if ($paren);
    print "(" if ($paren);
    print "<A HREF=\"$fullurl";
    print $barequery;
    print "\"";
    if ($open_extern_window && (!defined($mimetype) || $mimetype ne "text/x-cvsweb-markup")) {
	print " target=\"cvs_checkout\"";
	# we should have
	#   'if (document.cvswin==null) document.cvswin=window.open(...'
	# in order to allow the user to resize the window; otherwise
	# the user may resize the window, but on next checkout - zap -
	# its original (configured s. cvsweb.conf) size is back again
	# .. annoying (if $extern_window_(width|height) is defined)
	# but this if (..) solution is far from perfect
	# what we need to do as well is
	# 1) save cvswin in an invisible frame that always exists
	#    (document.cvswin will be void on next load)
	# 2) on close of the cvs_checkout - window set the cvswin
	#    variable to 'null' again - so that it will be
	#    reopenend with the configured size
	# anyone a JavaScript programmer ?
	# .. so here without if (..):
	# currently, the best way is to comment out the size parameters
	# ($extern_window...) in cvsweb.conf.
	if ($use_java_script) {
	    print " onClick=\"window.open('$fullurl','cvs_checkout',";
	    print "'resizeable,scrollbars";
	    print ",status,toolbar" if (defined($mimetype)
	        && $mimetype eq "text/html");
	    print ",width=$extern_window_width" if (defined($extern_window_width));
	    print ",height=$extern_window_height" if (defined($extern_window_height));
	    print"');\"";
	}
    }
    print "><b>$textlink</b></A>";
    print ")" if ($paren);
}

# Returns a Query string with the
# specified parameter toggled
sub toggleQuery($$) {
    my ($toggle,$value) = @_;
    my ($newquery,$var);
    my (%vars);
    %vars = %input;
    if (defined($value)) {
	$vars{$toggle} = $value;
    }
    else {
	$vars{$toggle} = $vars{$toggle} ? 0 : 1;
    }
    # Build a new query of non-default paramenters
    $newquery = "";
    foreach $var (@stickyvars) {
	my ($value) = defined($vars{$var}) ? $vars{$var} : "";
	my ($default) = defined($DEFAULTVALUE{$var}) ? $DEFAULTVALUE{$var} : "";
	if ($value ne $default) {
	    $newquery .= "&amp;" if ($newquery ne "");
	    $newquery .= urlencode($var) . "=" . urlencode($value);
	}
    }
    if ($newquery) {
	return '?' . $newquery;
    }
    return "";
}

sub urlencode($) {
    my ($in) = @_;
    my ($out);
    ($out = $in) =~ s/([\000-+{-\377])/sprintf("%%%02x", ord($1))/ge;
    return $out;
}

sub http_header(;$) {
    my $content_type = shift || "text/html";
    my $is_mod_perl = defined($ENV{'MOD_PERL'});
    if (defined($moddate)) {
	if ($is_mod_perl) {
	    Apache->request->header_out("Last-Modified" => scalar gmtime($moddate) . " GMT");
	}
	else {
	    print "Last-Modified: " . scalar gmtime($moddate) . " GMT\r\n";
	}
    }
    if ($is_mod_perl) {
	Apache->request->content_type($content_type);
    }
    else {
	    print "Content-type: $content_type\r\n";
    }
    if ($allow_compress && $maycompress) {
	if ($has_zlib || (defined($GZIPBIN) && open(GZIP, "|$GZIPBIN -1 -c"))) {
	    if ($is_mod_perl) {
		    Apache->request->content_encoding("x-gzip");
		    Apache->request->header_out(Vary => "Accept-Encoding");
		    Apache->request->send_http_header;
	    }
	    else {
		    print "Content-encoding: x-gzip\r\n";
		    print "Vary: Accept-Encoding\r\n";  #RFC 2068, 14.43
		    print "\r\n"; # Close headers
	    }
	    $| = 1; $| = 0; # Flush header output
	    if ($has_zlib) {
	    	tie *GZIP, __PACKAGE__, \*STDOUT;
	    }
	    select(GZIP);
	    $gzip_open = 1;
#	    print "<!-- gzipped -->" if ($content_type eq "text/html");
	}
	else {
	    if ($is_mod_perl) {
		    Apache->request->send_http_header;
	    }
	    else {
		    print "\r\n"; # Close headers
	    }
	    print "<font size=-1>Unable to find gzip binary in the \$PATH to compress output</font><br>";
	}
    }
    else {
	    if ($is_mod_perl) {
		    Apache->request->send_http_header;
	    }
	    else {
		    print "\r\n"; # Close headers
	    }
    }
}

sub html_header($) {
    &ui_print_header(undef, $text{'cvsweb_title'}, "");
#   if (!&has_command("rlog")) {
#	print "<p>",&text('cvsweb_ecmd', "<tt>rlog</tt>"),"<p>\n";
#	&ui_print_footer("", $text{'index_return'});
#	exit;
#	}
    if (!&has_command("rlog")) {
	$no_rlog++;
	}
    return;
}

sub html_footer() {
    &ui_print_footer("", $text{'index_return'});
    return undef;
}

sub link_tags($)
{
    my ($tags) = @_;
    my ($ret) = "";
    my ($fileurl,$filename);

    ($filename = $where) =~ s/^.*\///;
    $fileurl = urlencode($filename);

    foreach my $sym (split(", ", $tags)) {
	$ret .= ",\n" if ($ret ne "");
	$ret .= "<A HREF=\"$fileurl"
		. toggleQuery('only_with_tag',$sym) . "\">$sym</A>";
    }
    return $ret."\n";
}

#
# See if a module is listed in the config file's @HideModule list.
#
sub forbidden_module($) {
    my($module) = @_;
    return checkForbidden($module, @HideModules);
}

sub forbidden_file($) {
    my($file) = @_;
    $file =~ s|^.*/||;
    return checkForbidden($file, @DissallowRead);
}

sub checkForbidden($@) {
    my($item, @list) = @_;
    for (my $i=0; $i < @list; $i++) {
	return 1 if $item =~ $list[$i];
    }
    return 0;
}

# Close the GZIP handle remove the tie.

sub gzipclose() {
	if ($gzip_open) {
	    select(STDOUT);
	    close(GZIP);
	    untie *GZIP;
	    $gzip_open = 0;
	}
}

# implement a gzipped file handle via the Compress:Zlib compression
# library.

sub MAGIC1() { 0x1f }
sub MAGIC2() { 0x8b }
sub OSCODE() { 3    }

sub TIEHANDLE {
	my ($class, $out) = @_;
	my ($d) = Compress::Zlib::deflateInit(-Level => Compress::Zlib::Z_BEST_COMPRESSION(),
		-WindowBits => -Compress::Zlib::MAX_WBITS()) or return undef;
	my ($o) = {
		handle => $out,
		dh => $d,
		crc => 0,
		len => 0,
	};
	my ($header) = pack("c10", MAGIC1, MAGIC2, Compress::Zlib::Z_DEFLATED(), 0,0,0,0,0,0, OSCODE);
	print {$o->{handle}} $header;
	return bless($o, $class);
}

sub PRINT {
	my ($o) = shift;
	my ($buf) = join(defined $, ? $, : "",@_);
	my ($len) = length($buf);
	my ($compressed, $status) = $o->{dh}->deflate($buf);
	print {$o->{handle}} $compressed if defined($compressed);
	$o->{crc} = Compress::Zlib::crc32($buf, $o->{crc});
	$o->{len} += $len;
	return $len;
}

sub PRINTF {
	my ($o) = shift;
	my ($fmt) = shift;
	my ($buf) = sprintf($fmt, @_);
	my ($len) = length($buf);
	my ($compressed, $status) = $o->{dh}->deflate($buf);
	print {$o->{handle}} $compressed if defined($compressed);
	$o->{crc} = Compress::Zlib::crc32($buf, $o->{crc});
	$o->{len} += $len;
	return $len;
}

sub WRITE {
	my ($o, $buf, $len, $off) = @_;
	my ($compressed, $status) = $o->{dh}->deflate(substr($buf, 0, $len));
	print {$o->{handle}} $compressed if defined($compressed);
	$o->{crc} = Compress::Zlib::crc32(substr($buf, 0, $len), $o->{crc});
	$o->{len} += $len;
	return $len;
}

sub CLOSE {
	my ($o) = @_;
	return if !defined( $o->{dh});
	my ($buf) = $o->{dh}->flush();
	$buf .= pack("V V", $o->{crc}, $o->{len});
	print {$o->{handle}} $buf;
	undef $o->{dh};
}

sub DESTROY {
	my ($o) = @_;
	CLOSE($o);
}
