#!/usr/local/bin/perl
# index_top.cgi
# Display the top frame using the Caldera icons and style

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
$hostname = &get_display_hostname();
$ver = &get_webmin_version();
&ReadParse();
if ($gconfig{'real_os_type'}) {
	$ostr = "$gconfig{'real_os_type'} $gconfig{'real_os_version'}";
	}
else {
	$ostr = "$gconfig{'os_type'} $gconfig{'os_version'}";
	}

# Build a list of all modules
@modules = &get_visible_module_infos();

# Work out what categories exist, and which is current
%cats = &list_categories(\@modules);
@cats = sort { $b cmp $a } keys %cats;
$cats = @cats;
$per = $cats ? 100.0 / $cats : 100;
if (!defined($in{'cat'})) {
	# Use default category
	if (defined($gconfig{'deftab'})) {
		$in{'cat'} = $gconfig{'deftab'};
		}
	else {
		$in{'cat'} = $cats[0];
		}
	}
elsif (!$cats{$in{'cat'}}) {
	$in{'cat'} = "";
	}

# Display title and categories
&PrintHeader();
print <<EOF;
<!doctype html public "-//W3C//DTD HTML 3.2 Final//EN">
<HTML>

<HEAD>
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<LINK REL="stylesheet" TYPE="text/css" HREF="style.css">
</HEAD>

<BODY LINK="#FFFFFF" VLINK="#FFFFFF" MARGINWIDTH="0" MARGINHEIGHT="0" LEFTMARGIN="0" TOPMARGIN="0" BACKGROUND="images/navbg.gif">

  <TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0" WIDTH="100%" HEIGHT="1">
    <TR>
      <TD HEIGHT="35"  VALIGN="top" ALIGN="left" WIDTH=100% background="images/webmin-header.gif"><br></TD>
      <TD WIDTH="100%" HEIGHT="1" ALIGN="LEFT" VALIGN="BOTTOM" BACKGROUND="images/navbg.gif">
        <TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0" BACKGROUND="images/blue-bg.gif" WIDTH="100%">
          <TR>
EOF
foreach $c (@cats) {
	if ($in{'cat'} eq $c) {
		print "<TD width=1% HEIGHT=24 BACKGROUND=images/folder-on.gif VALIGN=TOP ALIGN=LEFT><IMG SRC=images/spacer.gif HEIGHT=6 WIDTH=72><BR><NOBR><IMG SRC=images/spacer.gif WIDTH=6 HEIGHT=1><TABLE WIDTH=72 CELLPADDING=0 CELLSPACING=0 BORDER=0 BACKGROUND=''><TR><TD><CENTER><SPAN CLASS=navActive2>$cats{$c}</SPAN></CENTER></TD></TR></TABLE></NOBR></TD>\n";
		}
	else {
		print "<TD width=1% HEIGHT=24 BACKGROUND=images/folder-off.gif VALIGN=TOP ALIGN=LEFT><IMG SRC=images/spacer.gif HEIGHT=6 WIDTH=72><BR><NOBR><IMG SRC=images/spacer.gif WIDTH=6 HEIGHT=1><TABLE WIDTH=72 CELLPADDING=0 CELLSPACING=0 BORDER=0 BACKGROUND=''><TR><TD><CENTER><A TARGET=top HREF='index_top.cgi?cat=$c' CLASS=navInactive>$cats{$c}</A></CENTER></TD></TR></TABLE></NOBR></TD>\n";
		}
	}
$vtext =&text('main_title', $ver, $hostname, $ostr)
	if (!$gconfig{'nohostname'});
if ($main::session_id) {
	$switch = "<a href='session_login.cgi?logout=1' target=_top CLASS=bodyNav>".
		  "$text{'main_logout'}</a>";
	}
else {
	$switch = "<a href=switch_user.cgi target=_top CLASS=bodyNav>".
	          "$text{'main_switch'}</a>";
	}
print <<EOF;
<TD WIDTH=1% HEIGHT="24" BACKGROUND="images/folder-off.gif" VALIGN="TOP" ALIGN="RIGHT"><IMG SRC="images/spacer.gif" HEIGHT="6" WIDTH="80"><BR><NOBR><A TARGET="_top" HREF="http://www.calderasystems.com/" CLASS="navInactive2">Home</A><SPAN CLASS="bodyText"> | </SPAN><A HREF="mailto:support\@calderasystems.com" CLASS="navInactive2">Feedback</A><IMG SRC="images/spacer.gif" HEIGHT="1" WIDTH="6"></NOBR></TD></TR></TABLE></TD>
          </TR>
        </TABLE>
      </TD>
    </TR>
    <TR>
      <TD COLSPAN="2" WIDTH="100%" HEIGHT="19">
        <TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0" WIDTH="100%">
          <TR>
            <TD BACKGROUND="images/gradient-bg.gif" WIDTH="75%" HEIGHT="19"><IMG SRC="images/spacer.gif" WIDTH="95" HEIGHT="1"><SPAN CLASS="EightPoint"><NOBR>$vtext</NOBR></SPAN></TD>
            <TD BACKGROUND="images/main-bg-pixel.gif" WIDTH="25%" HEIGHT="19" ALIGN=RIGHT>$switch</TD>
          </TR>
        </TABLE>
      </TD>
    </TR>
    <TR>
      <TD BACKGROUND="images/main-bg-pixel.gif" COLSPAN="2" WIDTH="100%" VALIGN="TOP" ALIGN="LEFT">
          <TABLE BACKGROUND="images/main-bg-pixel.gif" WIDTH="100%" BORDER="0" CELLPADDING="0" CELLSPACING="0">
EOF

# Display icons in this category
$pos = 0;
foreach $m (@modules) {
	next if ($m->{'category'} ne $in{'cat'});
	if ($pos % 3 == 0) { print "<tr>\n"; }
	local $lnk = $m->{'index_link'};
	local $img = -r "$theme_root_directory/$m->{'dir'}/images/icon.gif" ?
				"/$m->{'dir'}/images/icon.gif" :
				"/template.gif";
	print "<TD width=1%><A TARGET=body HREF='@{[&get_webprefix()]}/$m->{'dir'}/$lnk'><IMG SRC='@{[&get_webprefix()]}$img' WIDTH=55 HEIGHT=24 BORDER=0></A></TD><TD WIDTH=32%><A TARGET=body HREF='@{[&get_webprefix()]}/$m->{'dir'}/$lnk' CLASS=bodyNav>$m->{'desc'}</A></TD>\n";
	if ($pos++ % 3 == 2) { print "</tr>\n"; }
	}

print <<EOF;
<TR> <TD COLSPAN="6"><IMG SRC="images/spacer.gif" WIDTH="10" HEIGHT="100"></TD> </TR>
</TABLE> </TD> </TR> </TABLE>
</BODY>
</HTML>
EOF

