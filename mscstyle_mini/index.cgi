#!/usr/local/bin/perl

require './web-lib.pl';
@available = ("webmin", "system", "servers", "cluster", "hardware", "", "net");
&init_config();
$hostname = &get_display_hostname();
$ver = &get_webmin_version();
&get_miniserv_config(\%miniserv);
if ($gconfig{'real_os_type'}) {
	$ostr = "$gconfig{'real_os_type'} $gconfig{'real_os_version'}";
	}
else {
	$ostr = "$gconfig{'os_type'} $gconfig{'os_version'}";
	}
&ReadParse();

# Redirect if the user has only one module
@msc_modules = &get_visible_module_infos()
	if (!length(@msc_modules));
if (@msc_modules == 1 && $gconfig{'gotoone'}) {
	&redirect("$msc_modules[0]->{'dir'}/");
	exit;
	}

# Show standard header
$gconfig{'sysinfo'} = 0 if ($gconfig{'sysinfo'} == 1);
&header($gconfig{'nohostname'} ? $text{'main_title2'} :
	&text('main_title', $ver, $hostname, $ostr), "",
	undef, undef, 1, 1);

if (!@msc_modules) {
	# use has no modules!
	print "<p><b>$text{'main_none'}</b><p>\n";
	}
elsif ($gconfig{"notabs_${base_remote_user}"} == 2 ||
    $gconfig{"notabs_${base_remote_user}"} == 0 && $gconfig{'notabs'}) {
	# Generate main menu with all modules on one page
	print "<center><table cellpadding=0>\n";
	$pos = 0;
	$cols = $gconfig{'nocols'} ? $gconfig{'nocols'} : 4;
	$per = 100.0 / $cols;
	foreach $m (@msc_modules) {
		if ($pos % $cols == 0) { print "<tr>\n"; }
		print "<td valign=top align=center>\n";
		print "<table border><tr><td><a href=/$m->{'dir'}/>",
		      "<img src=$m->{'dir'}/images/icon.gif border=0 ",
		      "width=20 height=20></a></td></tr></table>\n";
		print "<a href=/$m->{'dir'}/>$m->{'desc'}</a></td>\n";
		if ($pos % $cols == $cols - 1) { print "</tr>\n"; }
		$pos++;
		}
	print "</table></center><p><table width='100%' bgcolor='#FFFFFF'><tr><td></td></tr></table>\n";
	}
else {
	# Generate categorized module list
	print "<table border=0 cellpadding=0 cellspacing=0 width=100% align=center><tr><td><table border=0 cellpadding=0 cellspacing=0 width=100% height=20><tr>\n";
	$usercol = defined($gconfig{'cs_header'}) ||
		   defined($gconfig{'cs_table'}) ||
		   defined($gconfig{'cs_page'});
	foreach $c (@cats) {
		$t = $cats{$c};
		if ($in{'cat'} eq $c) {
			print "<td bgcolor=#424242><b><font color=#FFFFFF><center>$t</center></font></b></td>\n";
			}
		}
	print "</tr></table>";
&make_sep;
	print "<table width=100% cellpadding=5>\n";

	# Display the modules in this category
	foreach $m (@msc_modules) {
		next if ($m->{'category'} ne $in{'cat'});

		print "<table width=100% border=0 cellpadding=0 cellspacing=0 bgcolor=#ffffff><tr><td><a href=/$m->{'dir'}/>",
		      "<img src=$m->{'dir'}/images/icon.gif alt=\"\" width=25 height=25 border=1></a>",
		      "</td><td width=100% bgcolor=#9e9aa2>\n";
		print "&nbsp;<a href=/$m->{'dir'}/>"; &chop_font2; print "</a></td></tr></table>\n";
&make_sep;
		}

	}

if ($miniserv{'logout'} && !$gconfig{'alt_startpage'} &&
    !$ENV{'SSL_USER'} && !$ENV{'LOCAL_USER'} &&
    $ENV{'HTTP_USER_AGENT'} !~ /webmin/i) {
	print "<table width=100% cellpadding=0 cellspacing=0><tr>\n";
	if ($gconfig{'skill_'.$base_remote_user}) {
		print "<td><b>$text{'main_skill'}:</b>\n";
		foreach $s ('high', 'medium', 'low') {
			print "&nbsp;|&nbsp;" if ($done_first_skill++);
			if ($gconfig{'skill_'.$base_remote_user} eq $s) {
				print $text{'skill_'.$s};
				}
			else {
				print "<a href='switch_skill.cgi?skill=$s&",
				   "cat=$in{'cat'}'>", "<font color=000000>", $text{'skill_'.$s},"</font></a>";
				}
			}
		print "</td>\n";
		}
	}

&footer();


sub chop_font {

        foreach $l (split(//, $t)) {
            $ll = ord($l);
            if ($ll > 127 && $lang->{'charset'}) {
                print "<img src=images/letters2/$ll.$lang->{'charset'}.gif alt=\"$l\" align=bottom border=0>";
                }
            elsif ($l eq " ") {
                print "<img src=images/letters2/$ll.gif alt=\"\&nbsp;\" align=bottom border=0>";
                }
            else {
                print "<img src=images/letters2/$ll.gif alt=\"$l\" align=bottom border=0>";
                }
            }

}

sub chop_font2 {

        foreach $l (split(//, $m->{'desc'})) {
            $ll = ord($l);
            if ($ll > 127 && $lang->{'charset'}) {
                print "<img src=images/letters2/$ll.$lang->{'charset'}.gif alt=\"$l\" align=middle border=0>";
                }
            elsif ($l eq " ") {
                print "<img src=images/letters2/$ll.gif alt=\"\&nbsp;\" align=middle border=0>";
                }
            else {
                print "<img src=images/letters2/$ll.gif alt=\"$l\" align=middle border=0>";
                }
            }

}

