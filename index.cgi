#!/usr/local/bin/perl
# Display all Webmin modules visible to the current user

require './web-lib.pl';
&init_config();
$hostname = &get_display_hostname();
$ver = &get_webmin_version();
&get_miniserv_config(\%miniserv);
if ($gconfig{'real_os_type'}) {
	if ($gconfig{'os_version'} eq "*") {
		$ostr = $gconfig{'real_os_type'};
		}
	else {
		$ostr = "$gconfig{'real_os_type'} $gconfig{'real_os_version'}";
		}
	}
else {
	$ostr = "$gconfig{'os_type'} $gconfig{'os_version'}";
	}
%access = &get_module_acl();

# Build a list of all modules
@modules = &get_visible_module_infos();

if (!defined($in{'cat'})) {
	# Maybe redirect to some module after login
	local $goto = &get_goto_module(\@modules);
	if ($goto) {
		&redirect($goto->{'dir'}.'/');
		exit;
		}
	}

$gconfig{'sysinfo'} = 0 if ($gconfig{'sysinfo'} == 1);
if ($gconfig{'alt_startpage'}) {
	# Tim's webmin header
	&header(&text('main_title', $ver, $hostname, $ostr));
	print "<TABLE class='header' id='alt_startpage' BORDER=0 WIDTH=100%>\n";
	print "<TR><TD WIDTH=20% ALIGN=left>\n";
	print "Version $ver<BR>$hostname<BR>$ostr</TD>";
	print "<TD WIDTH=60% ALIGN=center>\n";
	print "<IMG SRC=\"images/newlogo.gif\" BORDER=0>";
	print "</TD><TD WIDTH=20% ALIGN=right>";
	print "<a href=http://www.webmin.com/>$text{'main_homepage'}</a><br>";
	print "<a href=feedback_form.cgi>$text{'main_feedback'}</a>"
		if ($gconfig{'nofeedbackcc'} != 2 && $access{'feedback'});
	if ($miniserv{'logout'} && !$ENV{'SSL_USER'} && !$ENV{'LOCAL_USER'} &&
	    $ENV{'HTTP_USER_AGENT'} !~ /webmin/i) {
		print "<br><br>\n";
		if ($main::session_id) {
			print "<a href='session_login.cgi?logout=1'>",
			      "$text{'main_logout'}</a>";
			}
		else {
			print "<a href=switch_user.cgi>$text{'main_switch'}</a>";
			}
		}
	print "</TD></TR></TABLE><HR id='header_hr'><P>\n\n";
	}
else {
	# Standard webmin header
	if ($gconfig{'texttitles'}) {
		@args = ( $text{'main_title2'}, undef );
		}
	else {
		@args = ( $gconfig{'nohostname'} ? $text{'main_title2'} :
			    &text('main_title', $ver, $hostname, $ostr),
			  "images/webmin-blue.png" );
		if ($gconfig{'showlogin'}) {
			$args[0] = $remote_user." : ".$args[0];
			}
		}
	&header(@args, undef, undef, 1, 1,
		$tconfig{'brand'} ? 
		"<a href=$tconfig{'brand_url'}>$tconfig{'brand'}</a>" :
		$gconfig{'brand'} ? 
		"<a href=$gconfig{'brand_url'}>$gconfig{'brand'}</a>" :
		"<a href=http://www.webmin.com/>$text{'main_homepage'}</a>".
		($gconfig{'nofeedbackcc'} == 2 || !$access{'feedback'} ? "" :
		  "<br><a href=feedback_form.cgi>$text{'main_feedback'}</a>")
		);
	print "<center><font size=+1>",
	    &text('main_version', $ver, $hostname, $ostr),"</font></center>\n"
		if (!$gconfig{'nohostname'});
	print "<hr id='header_hr'><p>\n";
	}
print $text{'main_header'};

if (!@modules) {
	# use has no modules!
	print "<p class='main_none'><b>$text{'main_none'}</b><p>\n";
	}
elsif ($gconfig{"notabs_${base_remote_user}"} == 2 ||
    $gconfig{"notabs_${base_remote_user}"} == 0 && $gconfig{'notabs'}) {
	# Generate main menu with all modules on one page
	print "<center><table id='mods' cellpadding=5 cellspacing=0 width=100%>\n";
	$pos = 0;
	$cols = $gconfig{'nocols'} ? $gconfig{'nocols'} : 4;
	$per = 100.0 / $cols;
	foreach $m (@modules) {
		if ($pos % $cols == 0) { print "<tr $cb>\n"; }
		print "<td valign=top align=center width=$per\%>\n";
		local $idx = $m->{'index_link'};
		print "<table border><tr><td><a href=$gconfig{'webprefix'}/$m->{'dir'}/$idx>",
		      "<img src=$m->{'dir'}/images/icon.gif border=0 ",
		      "width=48 height=48></a></td></tr></table>\n";
		print "<a href=$gconfig{'webprefix'}/$m->{'dir'}/$idx>$m->{'desc'}</a></td>\n";
		if ($pos % $cols == $cols - 1) { print "</tr>\n"; }
		$pos++;
		}
	print "</table></center><p><hr id='mods_hr'>\n";
	}
else {
	# Display under categorised tabs
	&ReadParse();
	%cats = &list_categories(\@modules);
	@cats = sort { $b cmp $a } keys %cats;
	$cats = @cats;
	$per = $cats ? 100.0 / $cats : 100;
	if (!defined($in{'cat'})) {
		# Use default category
		if (defined($gconfig{'deftab'}) &&
		    &indexof($gconfig{'deftab'}, @cats) >= 0) {
			$in{'cat'} = $gconfig{'deftab'};
			}
		else {
			$in{'cat'} = $cats[0];
			}
		}
	elsif (!$cats{$in{'cat'}}) {
		$in{'cat'} = "";
		}
	print "<table id='cattabs' border=0 cellpadding=0 cellspacing=0 height=20><tr>\n";
	$usercol = defined($gconfig{'cs_header'}) ||
		   defined($gconfig{'cs_table'}) ||
		   defined($gconfig{'cs_page'});
	foreach $c (@cats) {
		$t = $cats{$c};
		if ($in{'cat'} eq $c) {
			print "<td class='usercoll' valign=top $cb>", $usercol ? "<br>" :
			  "<img src=images/lc2.gif alt=\"\">","</td>\n";
			print "<td class='usercolc' id='selectedcat' $cb>&nbsp;<b>$t</b>&nbsp;</td>\n";
			print "<td class='usercolr' valign=top $cb>", $usercol ? "<br>" :
			  "<img src=images/rc2.gif alt=\"\">","</td>\n";
			}
		else {
			print "<td class='usercoll' valign=top $tb>", $usercol ? "<br>" :
			  "<img src=images/lc1.gif alt=\"\">","</td>\n";
			print "<td class='usercolc' $tb>&nbsp;",
			      "<a href=$gconfig{'webprefix'}/?cat=$c><b>$t</b></a>&nbsp;</td>\n";
			print "<td class='usercolr' valign=top $tb>", $usercol ? "<br>" :
			  "<img src=images/rc1.gif alt=\"\">","</td>\n";
			}
		print "<td width=10></td>\n";
		}
	print "</tr></table> <table id='mods' border=0 cellpadding=0 cellspacing=0 ",
              "width=100% $cb>\n";
	print "<tr><td><table width=100% cellpadding=5>\n";

	# Display the modules in this category
	$pos = 0;
	$cols = $gconfig{'nocols'} ? $gconfig{'nocols'} : 4;
	$per = 100.0 / $cols;
	foreach $m (@modules) {
		next if ($m->{'category'} ne $in{'cat'});

		if ($pos % $cols == 0) { print "<tr>\n"; }
		local $idx = $m->{'index_link'};
		print "<td valign=top align=center width=$per\%>\n";
		print "<table border bgcolor=#ffffff><tr><td><a href=$gconfig{'webprefix'}/$m->{'dir'}/$idx>",
		      "<img src=$m->{'dir'}/images/icon.gif alt=\"\" border=0></a>",
		      "</td></tr></table>\n";
		print "<a href=$gconfig{'webprefix'}/$m->{'dir'}/$idx>$m->{'desc'}</a></td>\n";
		if ($pos++ % $cols == $cols - 1) { print "</tr>\n"; }
		}
	while($pos++ % $cols) {
		print "<td width=$per\%></td>\n";
		}
	print "</table></td></tr></table><p><hr id='mods_hr'>\n";
	}

# Check for incorrect OS
if (&foreign_available("webmin")) {
	&foreign_require("webmin", "webmin-lib.pl");
	%realos = &webmin::detect_operating_system(undef, 1);
	if ($realos{'os_version'} ne $gconfig{'os_version'} ||
	    $realos{'os_type'} ne $gconfig{'os_type'}) {
		print "<form action=webmin/fix_os.cgi>\n";
		print "<p><center>",&webmin::text('os_incorrect',
			$realos{'real_os_type'},
			$realos{'real_os_version'}),"<p>\n";
		print "<input type=submit ",
		      "value='$webmin::text{'os_fix'}'>\n";
		print "</center>\n";
		print "</form>\n";
		}
	}

if ($miniserv{'logout'} && !$gconfig{'alt_startpage'} &&
    !$ENV{'SSL_USER'} && !$ENV{'LOCAL_USER'} && !$ENV{'ANONYMOUS_USER'} &&
    $ENV{'HTTP_USER_AGENT'} !~ /webmin/i) {
	print "<table id='altlogout' width=100% cellpadding=0 cellspacing=0><tr>\n";
	if ($main::session_id) {
		print "<td align=right><a href='session_login.cgi?logout=1'>",
		      "$text{'main_logout'}</a></td>\n";
		}
	else {
		print "<td align=right><a href=switch_user.cgi>",
		      "$text{'main_switch'}</a></td>\n";
		}
	print "</tr></table>\n";
	}

print $text{'main_footer'};
&footer();

