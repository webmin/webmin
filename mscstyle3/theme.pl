#!/usr/local/bin/perl

#theme_prebody - called just before the main body of every page, so it can print any HTML it likes.
#theme_postbody - called just after the main body of every page.
#theme_header - called instead of the normal header function, with the same parameters. You could use this to re-write the header function in your own style with help and index links whereever you want them.
#theme_footer - called instead of the footer function with the same parameters.
#theme_error - called instead of the error function, with the same parameters.

%letter_sizes = (
	'100.gif', [ 10, 16 ],
	'101.gif', [ 11, 16 ],
	'102.gif', [ 6, 16 ],
	'103.gif', [ 10, 16 ],
	'104.gif', [ 9, 16 ],
	'105.gif', [ 4, 16 ],
	'106.gif', [ 5, 16 ],
	'107.gif', [ 9, 16 ],
	'108.gif', [ 4, 16 ],
	'109.gif', [ 14, 16 ],
	'110.gif', [ 9, 16 ],
	'111.gif', [ 11, 16 ],
	'112.gif', [ 10, 16 ],
	'113.gif', [ 10, 16 ],
	'114.gif', [ 6, 16 ],
	'115.gif', [ 8, 16 ],
	'116.gif', [ 6, 16 ],
	'117.gif', [ 9, 16 ],
	'118.gif', [ 10, 16 ],
	'119.gif', [ 13, 16 ],
	'120.gif', [ 10, 16 ],
	'121.gif', [ 10, 16 ],
	'122.gif', [ 8, 16 ],
	'123.gif', [ 7, 16 ],
	'124.gif', [ 4, 16 ],
	'125.gif', [ 7, 16 ],
	'126.gif', [ 9, 16 ],
	'177.iso-8859-2.gif', [ 10, 16 ],
	'179.iso-8859-2.gif', [ 7, 16 ],
	'182.iso-8859-2.gif', [ 9, 16 ],
	'188.iso-8859-2.gif', [ 9, 16 ],
	'191.iso-8859-2.gif', [ 9, 16 ],
	'192.gif', [ 12, 16 ],
	'193.gif', [ 12, 16 ],
	'194.gif', [ 11, 16 ],
	'195.gif', [ 12, 16 ],
	'196.gif', [ 12, 16 ],
	'197.gif', [ 12, 16 ],
	'198.gif', [ 13, 16 ],
	'199.gif', [ 12, 16 ],
	'200.gif', [ 7, 16 ],
	'201.gif', [ 8, 16 ],
	'202.gif', [ 8, 16 ],
	'203.gif', [ 7, 16 ],
	'204.gif', [ 6, 16 ],
	'205.gif', [ 5, 16 ],
	'206.gif', [ 7, 16 ],
	'207.gif', [ 7, 16 ],
	'208.gif', [ 11, 16 ],
	'208.iso-8859-9.gif', [ 13, 16 ],
	'209.gif', [ 10, 16 ],
	'210.gif', [ 13, 16 ],
	'211.gif', [ 13, 16 ],
	'211.iso-8859-2.gif', [ 13, 16 ],
	'212.gif', [ 12, 16 ],
	'213.gif', [ 13, 16 ],
	'214.gif', [ 13, 16 ],
	'214.iso-8859-9.gif', [ 13, 16 ],
	'215.gif', [ 9, 16 ],
	'216.gif', [ 13, 16 ],
	'217.gif', [ 9, 16 ],
	'218.gif', [ 9, 16 ],
	'219.gif', [ 9, 16 ],
	'220.gif', [ 9, 16 ],
	'220.iso-8859-9.gif', [ 9, 16 ],
	'221.gif', [ 11, 16 ],
	'221.iso-8859-9.gif', [ 5, 16 ],
	'222.gif', [ 9, 16 ],
	'222.iso-8859-9.gif', [ 11, 16 ],
	'223.gif', [ 9, 16 ],
	'224.gif', [ 10, 16 ],
	'225.gif', [ 10, 16 ],
	'226.gif', [ 11, 16 ],
	'227.gif', [ 10, 16 ],
	'228.gif', [ 10, 16 ],
	'229.gif', [ 11, 16 ],
	'230.gif', [ 16, 16 ],
	'230.iso-8859-2.gif', [ 9, 16 ],
	'231.gif', [ 10, 16 ],
	'231.iso-8859-9.gif', [ 10, 16 ],
	'231.iso.8859-9.gif', [ 10, 16 ],
	'232.gif', [ 11, 16 ],
	'233.gif', [ 11, 16 ],
	'234.gif', [ 11, 16 ],
	'234.iso-8859-2.gif', [ 9, 16 ],
	'235.gif', [ 11, 16 ],
	'236.gif', [ 6, 16 ],
	'237.gif', [ 6, 16 ],
	'238.gif', [ 6, 16 ],
	'239.gif', [ 7, 16 ],
	'240.gif', [ 10, 16 ],
	'240.iso-8859-9.gif', [ 10, 16 ],
	'241.gif', [ 9, 16 ],
	'241.iso-8859-2.gif', [ 9, 16 ],
	'242.gif', [ 11, 16 ],
	'243.gif', [ 11, 16 ],
	'243.iso-8859-2.gif', [ 11, 16 ],
	'244.gif', [ 11, 16 ],
	'245.gif', [ 11, 16 ],
	'246.gif', [ 11, 16 ],
	'246.iso-8859-9.gif', [ 11, 16 ],
	'247.gif', [ 9, 16 ],
	'248.gif', [ 10, 16 ],
	'249.gif', [ 9, 16 ],
	'250.gif', [ 9, 16 ],
	'251.gif', [ 9, 16 ],
	'252.gif', [ 9, 16 ],
	'252.iso-8859-9.gif', [ 9, 16 ],
	'253.gif', [ 10, 16 ],
	'253.iso-8859-9.gif', [ 5, 16 ],
	'254.gif', [ 10, 16 ],
	'255.gif', [ 9, 16 ],
	'32.gif', [ 6, 16 ],
	'33.gif', [ 4, 16 ],
	'34.gif', [ 7, 16 ],
	'35.gif', [ 9, 16 ],
	'36.gif', [ 8, 16 ],
	'37.gif', [ 13, 16 ],
	'38.gif', [ 11, 16 ],
	'39.gif', [ 3, 16 ],
	'40.gif', [ 6, 16 ],
	'41.gif', [ 6, 16 ],
	'42.gif', [ 7, 16 ],
	'43.gif', [ 9, 16 ],
	'44.gif', [ 4, 16 ],
	'45.gif', [ 6, 16 ],
	'46.gif', [ 4, 16 ],
	'47.gif', [ 7, 16 ],
	'48.gif', [ 9, 16 ],
	'49.gif', [ 6, 16 ],
	'50.gif', [ 9, 16 ],
	'51.gif', [ 9, 16 ],
	'52.gif', [ 10, 16 ],
	'53.gif', [ 9, 16 ],
	'54.gif', [ 10, 16 ],
	'55.gif', [ 8, 16 ],
	'56.gif', [ 9, 16 ],
	'57.gif', [ 10, 16 ],
	'58.gif', [ 5, 16 ],
	'59.gif', [ 4, 16 ],
	'60.gif', [ 9, 16 ],
	'61.gif', [ 10, 16 ],
	'62.gif', [ 10, 16 ],
	'63.gif', [ 9, 16 ],
	'64.gif', [ 12, 16 ],
	'65.gif', [ 12, 16 ],
	'66.gif', [ 9, 16 ],
	'67.gif', [ 12, 16 ],
	'68.gif', [ 10, 16 ],
	'69.gif', [ 7, 16 ],
	'70.gif', [ 7, 16 ],
	'71.gif', [ 13, 16 ],
	'72.gif', [ 9, 16 ],
	'73.gif', [ 5, 16 ],
	'74.gif', [ 8, 16 ],
	'75.gif', [ 9, 16 ],
	'76.gif', [ 8, 16 ],
	'77.gif', [ 12, 16 ],
	'78.gif', [ 10, 16 ],
	'79.gif', [ 12, 16 ],
	'80.gif', [ 9, 16 ],
	'81.gif', [ 13, 16 ],
	'82.gif', [ 9, 16 ],
	'83.gif', [ 9, 16 ],
	'84.gif', [ 8, 16 ],
	'85.gif', [ 9, 16 ],
	'86.gif', [ 11, 16 ],
	'87.gif', [ 14, 16 ],
	'88.gif', [ 11, 16 ],
	'89.gif', [ 11, 16 ],
	'90.gif', [ 9, 16 ],
	'91.gif', [ 5, 16 ],
	'93.gif', [ 6, 16 ],
	'94.gif', [ 9, 16 ],
	'95.gif', [ 9, 16 ],
	'96.gif', [ 6, 16 ],
	'97.gif', [ 11, 16 ],
	'98.gif', [ 10, 16 ],
	'99.gif', [ 10, 16 ]
	);

sub theme_header {

local @available = ("webmin", "system", "servers", "cluster", "hardware", "", "net", "kororaweb");
my $module_name = &get_module_name();
my %module_info = &get_module_info($module_name);

local $ll;
local %access = &get_module_acl();
local %gaccess = &get_module_acl(undef, "");
print "<!doctype html public \"-//W3C//DTD HTML 3.2 Final//EN\">\n";
print "<html>\n";
local $os_type = $gconfig{'real_os_type'} ? $gconfig{'real_os_type'}
                      : $gconfig{'os_type'};
local $os_version = $gconfig{'real_os_version'} ? $gconfig{'real_os_version'}
                            : $gconfig{'os_version'};
print "<head>\n";
if ($charset) {
    print "<meta http-equiv=\"Content-Type\" ",
          "content=\"text/html; Charset=$charset\">\n";
    }
print "<link rel='icon' href='$gconfig{'webprefix'}/images/webmin_icon.png' type='image/png'>\n";
if (@_ > 0) {
    local $title = &get_html_title($_[0]);
    print "<title>$title</title>\n";
    print $_[7] if ($_[7]);
    if ($gconfig{'sysinfo'} == 0 && $remote_user) {
	print &get_html_status_line(0);
        }
    }

@msc_modules = &get_visible_module_infos()
	if (!length(@msc_modules));

print "</head>\n";
local $dir = $current_lang_info->{'dir'} ? "dir=\"$current_lang_info->{'dir'}\""
					 : "";
if ($theme_no_table) {
	print '<body bgcolor=#6696bc link=#000000 vlink=#000000 text=#000000 leftmargin="0" topmargin="0" marginwidth="0" marginheight="0" '.$dir.' '.$_[8].'>';
	}
else {
	print '<body bgcolor=#6696bc link=#000000 vlink=#000000 text=#000000 leftmargin="0" topmargin="0" marginwidth="0" marginheight="0" '.$dir.' '.$_[8].'>';
	}

if ($remote_user && @_ > 1) {
	# Show basic header with webmin.com link and logout button
	local $logout = $main::session_id ? "/session_login.cgi?logout=1"
					  : "/switch_user.cgi";
	local $loicon = $main::session_id ? "logout.jpg" : "switch.jpg";
	local $lowidth = $main::session_id ? 84 : 27;
	local $lotext = $main::session_id ? $text{'main_logout'}
					  : $text{'main_switch'};
	print qq~<table width="100%" border="0" cellspacing="0" cellpadding="0" background="$gconfig{'webprefix'}/images/top_bar/bg.jpg" height="32">
	  <tr>
	    <td width="4" nowrap><img src="$gconfig{'webprefix'}/images/top_bar/left.jpg" width="4" height="32"></td>
	    <td width="100%" nowrap><a href="http://www.webmin.com"><img src="$gconfig{'webprefix'}/images/top_bar/webmin_logo.jpg" width="99" height="32" border="0" alt="Webmin home page"></a></td>~;
	if (!$ENV{'ANONYMOUS_USER'}) {
		if ($gconfig{'nofeedbackcc'} != 2 && $gaccess{'feedback'} &&
		    (!$module_name || $module_info{'longdesc'} || $module_info{'feedback'})) {
			print qq~<td><a href='$gconfig{'webprefix'}/feedback_form.cgi?module=$module_name'><img src=$gconfig{'webprefix'}/images/top_bar/feedback.jpg width=97 height=32 alt="$text{'main_feedback'}" border=0></a></td>~;
			}
		if (!$ENV{'SSL_USER'} && !$ENV{'LOCAL_USER'} &&
		    !$ENV{'HTTP_WEBMIN_SERVERS'}) {
			if ($gconfig{'nofeedbackcc'} != 2 &&
			    $gaccess{'feedback'}) {
				print qq~<td><img src=$gconfig{'webprefix'}/images/top_bar/top_sep.jpg width=12 height=32></td>~;
				}
			print qq~<td width="84" nowrap><a href='$gconfig{'webprefix'}$logout'><img src="$gconfig{'webprefix'}/images/top_bar/$loicon" height="31" width=$lowidth border="0" alt="$lotext"></a></td>~;
			}
		}
	print qq~<td width="3" nowrap>
	      <div align="right"><img src="$gconfig{'webprefix'}/images/top_bar/right.jpg" width="3" height="32"></div>
	    </td>
	  </tr>
	</table>~;
	}

local $one = @msc_modules == 1 && $gconfig{'gotoone'};
local $notabs = $gconfig{"notabs_${base_remote_user}"} == 2 ||
	$gconfig{"notabs_${base_remote_user}"} == 0 && $gconfig{'notabs'};
if (@_ > 1 && !$one && $remote_user && !$notabs) {
    # Display module categories
    print qq~<table width="100%" border="0" cellspacing="0" cellpadding="0" height="7">
  <tr>
    <td background="$gconfig{'webprefix'}/images/top_bar/shadow_bg.jpg" nowrap><img src="$gconfig{'webprefix'}/images/top_bar/shadow.jpg" width="8" height="7"></td>
  </tr>
</table>~;

    # Get categories
    %cats = &list_categories(\@msc_modules);
    @cats = sort { $b cmp $a } keys %cats;
    $cats = @cats;
    $per = $cats ? 100.0 / $cats : 100;

    if ($main::theme_index_page) {
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
    }

#####Navigation Bar START#####
    print qq~<table width="100%" border="0" cellspacing="0" cellpadding="0" height="57" background="$gconfig{'webprefix'}/images/nav/bg.jpg">
  <tr background="$gconfig{'webprefix'}/images/nav/bg.jpg">
    <td width="6" nowrap><img src="$gconfig{'webprefix'}/images/nav/left.jpg" width="3" height="57"></td>~;

    foreach $c (@cats) {
        local $t = $cats{$c};
           $inlist    = "false";
           foreach $testet (@available) {
               if ($testet eq $c) {
                $inlist = "true";
               } 
            }
        local $catdesc = $text{'longcategory_'.$c};
        if ($in{'cat'} eq $c && $theme_index_page) {
           if ($inlist eq "true") {

              if ($c eq "") {
                print qq~<td nowrap><center><img src="$gconfig{'webprefix'}/images/cats_over/others.jpg" width="43" height="44" title="$catdesc"><br>~;
            &chop_font;

                          print qq~</center></td>
    <td width="17" nowrap><img src="$gconfig{'webprefix'}/images/nav/sep.jpg" width="17" height="57"></td>~; 
              } elsif ($c eq "webmin") {
               if (@_ > 1) {
               print qq~<td nowrap><center><a href=$gconfig{'webprefix'}/?cat=$c><img src="$gconfig{'webprefix'}/images/cats_over/$c.jpg" width="43" height="44" border=0 title="$catdesc"><br>~;
            &chop_font;
                          print qq~</a></center></td>
    <td width="17" nowrap><img src="$gconfig{'webprefix'}/images/nav/sep.jpg" width="17" height="57"></td>~;
                } else {
               print qq~<td nowrap><center><img src="$gconfig{'webprefix'}/images/cats_over/$c.jpg" width="43" height="44" border=0 title="$catdesc"><br>~;            &chop_font;
                          print qq~</center></td>
    <td width="17" nowrap><img src="$gconfig{'webprefix'}/images/nav/sep.jpg" width="17" height="57"></td>~;
                }
               } else {
               print qq~<td nowrap><center><img src="$gconfig{'webprefix'}/images/cats_over/$c.jpg" width="43" height="44" title="$catdesc"><br>~;

            &chop_font;

               print qq~</center></td>
    <td width="17" nowrap><img src="$gconfig{'webprefix'}/images/nav/sep.jpg" width="17" height="57"></td>~;
              }

        } else {
            print qq~<td nowrap><center><img src="$gconfig{'webprefix'}/images/cats_over/unknown.jpg" width="43" height="44" title="$catdesc"><br>~;

            &chop_font;

            print qq~</center></td>
    <td width="17" nowrap><img src="$gconfig{'webprefix'}/images/nav/sep.jpg" width="17" height="57"></td>~;
           }
        }
        else {
            if ($inlist eq "true") {
              if ($c eq "") {
                print qq~<td nowrap><center><a href=$gconfig{'webprefix'}/?cat=$c><img src="$gconfig{'webprefix'}/images/cats/others.jpg" width="43" height="44" border=0 alt="$t" title="$catdesc"><br>~;

            &chop_font;

                print qq~</a></center></td>
    <td width="17" nowrap><img src="$gconfig{'webprefix'}/images/nav/sep.jpg" width="17" height="57"></td>~; 
              } else {
               print qq~<td nowrap><center><a href=$gconfig{'webprefix'}/?cat=$c><img src="$gconfig{'webprefix'}/images/cats/$c.jpg" width="43" height="44" border=0 alt="$t" title="$catdesc"><br>~;

            &chop_font;

               print qq~</a></center></td>
    <td width="17" nowrap><img src="$gconfig{'webprefix'}/images/nav/sep.jpg" width="17" height="57"></td>~;
              }
        } else {
            print qq~<td nowrap><center><a href=$gconfig{'webprefix'}/?cat=$c><img src="$gconfig{'webprefix'}/images/cats/unknown.jpg" width="43" height="44" border=0 alt="$t" title="$catdesc"><br>~;

            &chop_font;

            print qq~</a></center></td>
    <td width="17" nowrap><img src="$gconfig{'webprefix'}/images/nav/sep.jpg" width="17" height="57"></td>~;
        }
           
            }
        }

    print qq~<td width="100%" nowrap>&nbsp;</td>
    <td nowrap>&nbsp;</td>
  </tr>
</table>~;
    print qq~<table width="100%" border="0" cellspacing="0" cellpadding="0" background="$gconfig{'webprefix'}/images/nav/bottom_bg.jpg" height="4">
  <tr>
    <td width="100%"><img src="$gconfig{'webprefix'}/images/nav/bottom_left.jpg" width="3" height="4"></td>
  </tr>
</table>~;
   }

if (@_ > 1 && (!$_[5] || $ENV{'HTTP_WEBMIN_SERVERS'})) {
   # Show tabs under module categories
   print qq~<table width="100%" border="0" cellspacing="0" cellpadding="0" background="$gconfig{'webprefix'}/images/nav/bottom_shadow2.jpg"> <tr background="$gconfig{'webprefix'}/images/nav/bottom_shadow2.jpg">~;

   if ($gconfig{'sysinfo'} == 2 && $remote_user) {
	&tab_start();
	print &get_html_status_line(1);
	&tab_end();
	}
   if ($ENV{'HTTP_WEBMIN_SERVERS'}) {
	&tab_start();
	print "<a href='$ENV{'HTTP_WEBMIN_SERVERS'}'>",
	      "$text{'header_servers'}</a><br>\n";
	&tab_end();
	}
	if ($notabs && !$_[5]) { 
		&tab_start;
		print "<a href='$gconfig{'webprefix'}/?cat=$module_info{'category'}'>$text{'header_webmin'}</a><br>\n";
		&tab_end;
		}
	if (!$_[4]) {
		local $idx = $module_info{'index_link'};
		local $mi = $module_index_link ||
			    $module_name ? "/$module_name/$idx" : "/";
		local $mt = $module_index_name || $text{'header_module'};
		&tab_start; print "<a href=\"$gconfig{'webprefix'}$mi\">",
			    "$mt</a>"; &tab_end;
		}
	if (ref($_[2]) eq "ARRAY" && !$ENV{'ANONYMOUS_USER'}) {
		&tab_start; print &hlink($text{'header_help'}, $_[2]->[0], $_[2]->[1]); &tab_end;
		}
	elsif (defined($_[2]) && !$ENV{'ANONYMOUS_USER'}) {
		&tab_start; print &hlink($text{'header_help'}, $_[2]); &tab_end;
		}
	if ($_[3]) {
		if (!$access{'noconfig'}) {
			&tab_start; print "<a href=\"$gconfig{'webprefix'}/config.cgi?$module_name\">",
			      $text{'header_config'},"</a>"; &tab_end;
			}
		}

    local $t;
    foreach $t (split(/<br>/, $_[6])) {
      if ($t =~ /\S/) {
	      &tab_start; print $t; &tab_end;
      }
    }

print qq~
    <td nowrap width="100%" background="$gconfig{'webprefix'}/images/nav/bottom_shadow2.jpg" valign="top">

      <table width="100%" border="0" cellspacing="0" cellpadding="0" background="$gconfig{'webprefix'}/images/nav/bottom_shadow2.jpg">
        <tr>
          <td><img src="$gconfig{'webprefix'}/unauthenticated/nav/bottom_shadow.jpg" width="43" height="9"></td>
        </tr>
      </table>


    </td>
  </tr>
</table>~;

    if (!$_[5]) {
	    # Show page title in tab
	    local $title = $_[0];
	    print "<p><table border=0 cellpadding=0 cellspacing=0 width=95% align=center><tr><td><table border=0 cellpadding=0 cellspacing=0 height=20><tr>\n";
	    print "<td bgcolor=#bae3ff valign=top>",
	      "<img src=$gconfig{'webprefix'}/images/tabs/blue_left.jpg width=13 height=22 ",
	      "alt=\"\">","</td>\n";
	    print "<td bgcolor=#bae3ff>&nbsp;<b>$title</b>&nbsp;</td>\n";
	    print "<td bgcolor=#bae3ff valign=top>",
	      "<img src=$gconfig{'webprefix'}/images/tabs/blue_right.jpg width=19 height=22 ",
	      "alt=\"\">","</td>\n";
	    if ($_[9]) {
		print "</tr></table></td> <td align=right><table border=0 cellpadding=0 cellspacing=0 height=20><tr>\n";
		print "<td bgcolor=#bae3ff>",
		      "<img src=$gconfig{'webprefix'}/images/tabs/blue_left.jpg width=13 height=22 ",
		      "alt=\"\">","</td>\n";
		print "<td bgcolor=#bae3ff>&nbsp;<b>$_[9]</b>&nbsp;</td>\n";
		print "<td bgcolor=#bae3ff>",
		      "<img src=$gconfig{'webprefix'}/images/tabs/blue_right.jpg width=19 height=22",
		      " alt=\"\">","</td>\n";
		}
	    print "</tr></table></td></tr></table>"; 

	     &theme_prebody;
	}
    } elsif (@_ > 1) {
	    print qq~<table width="100%" border="0" cellspacing="0" cellpadding="0" background="$gconfig{'webprefix'}/unauthenticated/nav/bottom_shadow.jpg">
	  <tr>
	    <td width="100%" nowrap><img src="$gconfig{'webprefix'}/unauthenticated/nav/bottom_shadow.jpg" width="43" height="9"></td>
	  </tr>
	</table><br>~;
    }
@header_arguments = @_;
}

sub theme_prebody
{
if ($theme_no_table) {
	print "<ul>\n";
	}
else {
	#print "<table border=0 width=95% align=center cellspacing=0 cellpadding=0><tr><td background=$gconfig{'webprefix'}/images/msctile2.jpg>\n";
	print "<table border=0 width=95% align=center cellspacing=0 cellpadding=0><tr><td bgcolor=#ffffff>\n";
	print "<table border=0 width=95% align=center cellspacing=0 cellpadding=0><tr><td>\n";
	}
}

sub theme_footer {
local $i;
my $module_name = &get_module_name();
my %module_info = &get_module_info($module_name);

if ($theme_no_table) {
	print "</ul>\n";
	}
elsif (@header_arguments > 1 && !$header_arguments[5]) {
	print "<br>\n</table></table><br>\n";
	}

print "<table border=0 width=100% align=center cellspacing=0 cellpadding=0><tr><td>\n";

for($i=0; $i+1<@_; $i+=2) {
    local $url = $_[$i];
    if ($url eq '/') {
        $url = "/?cat=$module_info{'category'}";
        }
    elsif ($url eq '' && $module_name) {
	local $idx = $module_info{'index_link'};
        $url = "/$module_name/$idx";
        }
    elsif ($url =~ /^\?/ && $module_name) {
        $url = "/$module_name/$url";
        }
    $url = "$gconfig{'webprefix'}$url" if ($url =~ /^\//);
    if ($i == 0) {
        print "&nbsp;<a href=\"$url\"><img alt=\"<-\" align=middle border=0 src=$gconfig{'webprefix'}/images/arrow.jpg></a>\n";
        }
    else {
        print "&nbsp;|\n";
        }
    print "&nbsp;<a href=\"$url\">",&text('main_return', $_[$i+1]),"</a>\n";
    }
print "</td></tr></table>\n";

print "<br>\n";
if (!$_[$i]) {
    if (defined(&theme_postbody)) {
        &theme_postbody(@_);
        }
    print "</body></html>\n";
    }

}

sub chop_font
{
print $t;
}

sub tab_start {
    print qq~    <td nowrap>
      <table border="0" cellspacing="0" cellpadding="0">
        <tr>
          <td background="$gconfig{'webprefix'}/images/tabs/bg.jpg"><img src="$gconfig{'webprefix'}/images/tabs/left.jpg" width="12" height="21" nowrap></td>
          <td background="$gconfig{'webprefix'}/images/tabs/bg.jpg" nowrap>
          ~;
}


sub tab_end {
     print qq~</td>
          <td background="$gconfig{'webprefix'}/images/tabs/bg.jpg" nowrap><img src="$gconfig{'webprefix'}/images/tabs/right.jpg" width="15" height="21"></td>
        </tr>
        <tr>
          <td nowrap><img src="$gconfig{'webprefix'}/images/tabs/right_bottom.jpg" width="12" height="4"></td>
          <td background="$gconfig{'webprefix'}/images/tabs/bottom.jpg" nowrap><img src="$gconfig{'webprefix'}/images/tabs/bottom.jpg" width="17" height="4"></td>
          <td nowrap><img src="$gconfig{'webprefix'}/images/tabs/left_bottom.jpg" width="15" height="4"></td>        </tr>
      </table>

    </td>~;
}

sub theme_ui_post_header
{
local ($text) = @_;
local $rv;
if (defined($text)) {
	$rv .= "<center><font size=+1>$text</font></center>\n";
	}
if ($main::printed_unbuffered_header) {
	$rv .= "<hr>\n";
	}
elsif (!defined($text)) {
	$rv .= "<br>\n";
	}
return $rv;
}

sub theme_ui_pre_footer
{
local $rv;
if ($main::printed_unbuffered_header) {
	$rv .= "<hr>\n";
	}
return $rv;
}

sub theme_error
{
&header($text{'error'}, "");
print "<br>\n";
print "<h3>",($main::whatfailed ? "$main::whatfailed : " : ""),@_,"</h3>\n";
if ($gconfig{'error_stack'}) {
	# Show call stack (skipping this function!)
	print "<h3>$text{'error_stack'}</h3>\n";
	print "<table>\n";
	print "<tr> <td><b>$text{'error_file'}</b></td> ",
	      "<td><b>$text{'error_line'}</b></td> ",
	      "<td><b>$text{'error_sub'}</b></td> </tr>\n";
	for($i=1; my @stack = caller($i); $i++) {
		print "<tr>\n";
		print "<td>$stack[1]</td>\n";
		print "<td>$stack[2]</td>\n";
		print "<td>$stack[3]</td>\n";
		print "</tr>\n";
		}
	print "</table>\n";
	}
if ($ENV{'HTTP_REFERER'} && $main::completed_referers_check) {
	&footer($ENV{'HTTP_REFERER'}, $text{'error_previous'});
	}
else {
	&footer();
	}
}

sub theme_ui_print_unbuffered_header
{
$| = 1;
$theme_no_table = 1;
$main::printed_unbuffered_header = 1;
&ui_print_header(@_);
}

# theme_ui_subheading(text, ...)
# Returns HTML for a section heading
sub theme_ui_subheading
{
return "<font size=+1>".join("", @_)."</font><br>\n";
}

# theme_popup_header(title, headstuff, bodystuff)
sub theme_popup_header
{
print "<!doctype html public \"-//W3C//DTD HTML 3.2 Final//EN\">\n";
print "<html>\n";
print "<title>$_[0]</title>\n";
print $_[1];
print "</head>\n";
local $margin = $_[0] ? 2 : 0;
print "<body bgcolor=#6696bc link=#000000 vlink=#000000 text=#000000 leftmargin=$margin topmargin=$margin marginwidth=$margin marginheight=$margin $_[2]>\n";
}

sub theme_popup_footer
{
print "</body></html>\n";
}

1;

