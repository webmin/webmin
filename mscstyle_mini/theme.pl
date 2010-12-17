#!/usr/local/bin/perl

#theme_prebody - called just before the main body of every page, so it can print any HTML it likes.
#theme_postbody - called just after the main body of every page.
#theme_header - called instead of the normal header function, with the same parameters. You could use this to re-write the header function in your own style with help and index links whereever you want them.
#theme_footer - called instead of the footer function with the same parameters.
#theme_error - called instead of the error function, with the same parameters.


sub theme_header {

local @available = ("webmin", "system", "servers", "cluster", "hardware", "", "net", "kororaweb");

local($ll, %access);
print "<!doctype html public \"-//W3C//DTD HTML 3.2 Final//EN\">\n";
print "<html>\n";
if ($charset) {
    print "<meta http-equiv=\"Content-Type\" ",
          "content=\"text/html; Charset=$charset\">\n";
    }
local $os_type = $gconfig{'real_os_type'} ? $gconfig{'real_os_type'}
                      : $gconfig{'os_type'};
local $os_version = $gconfig{'real_os_version'} ? $gconfig{'real_os_version'}
                            : $gconfig{'os_version'};
print "<head>\n";
if (@_ > 0) {
    if ($gconfig{'sysinfo'} == 1) {
        printf "<title>%s : %s on %s (%s %s)</title>\n",
            $_[0], $remote_user, &get_display_hostname(),
            $os_type, $os_version;
        }
    elsif ($gconfig{'sysinfo'} == 4) {
        printf "<title>%s on %s (%s %s)</title>\n",
            $remote_user, &get_display_hostname(),
            $os_type, $os_version;
        }
    else {
        print "<title>$_[0]</title>\n";
        }
    print $_[7] if ($_[7]);
    if ($gconfig{'sysinfo'} == 0 && $remote_user) {
        print "<SCRIPT LANGUAGE=\"JavaScript\">\n";
        printf
        "defaultStatus=\"%s%s logged into Webmin %s on %s (%s %s)\";\n",
            $remote_user,
            $ENV{'SSL_USER'} ? " (SSL certified)" :
            $ENV{'LOCAL_USER'} ? " (Local user)" : "",
            &get_webmin_version(), &get_display_hostname(),
            $os_type, $os_version;
        print "</SCRIPT>\n";
        }
    }

@msc_modules = &get_visible_module_infos()
	if (!scalar(@msc_modules));

print '<body bgcolor=#424242 link=#000000 vlink=#000000 text=#000000 leftmargin="0" topmargin="0" marginwidth="0" marginheight="0" '.$_[8].'>';

if ($remote_user && @_ > 1) {
	# Show basic header with webmin.com link and logout button
	local $logout = $main::session_id ? "/session_login.cgi?logout=1"
					  : "/switch_user.cgi";
	print qq~<table width="100%" border="0" cellspacing="0" cellpadding="0" background="/images/top_bar.jpg">
	  <tr>
	    <td width="100%" nowrap><a href="http://www.webmin.com"><img src="/images/webmin_top.jpg" border="0" alt="Webmin home page"></a></td>
	    <td nowrap><a href='$logout'><img src="/images/logout.jpg" border="0" alt="$text{'main_logout'}"></a></td>
	  </tr>
	</table>~;
	}

local $one = @msc_modules == 1 && $gconfig{'gotoone'};
if (@_ > 1 && !$one && $remote_user) {
    # Display module categories
    print qq~<table width="100%" border="0" cellspacing="0" cellpadding="0">
  <tr>
    <td background="/images/shadow.jpg" nowrap><img src="/images/shadow.jpg"></td>
  </tr>
</table>~;

    &read_file("$config_directory/webmin.catnames", \%catnames);
    foreach $m (@msc_modules) {
        $c = $m->{'category'};
        next if ($cats{$c});
        if (defined($catnames{$c})) {
            $cats{$c} = $catnames{$c};
            }
        elsif ($text{"category_$c"}) {
            $cats{$c} = $text{"category_$c"};
            }
        else {
            # try to get category name from module ..
            local %mtext = &load_language($m->{'dir'});
            if ($mtext{"category_$c"}) {
                $cats{$c} = $mtext{"category_$c"};
                }
            else {
                $c = $m->{'category'} = "";
                $cats{$c} = $text{"category_$c"};
                }
            }
        }
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

#####Navigation Bar START#####
    print qq~<table width="100%" border="0" cellspacing="0" cellpadding="0" bgcolor="#848484">
  <tr><td><center>~;

    foreach $c (@cats) {
        $t = $cats{$c};
           $inlist    = "false";
           foreach $testet (@available) {
               if ($testet eq $c) {
                $inlist = "true";
               } 
            }
        if ($in{'cat'} eq $c) {
           if ($inlist eq "true") {

              if ($c eq "") {
                print qq~<img src="/images/cats_over/others.jpg">~;

              } elsif ($c eq "webmin") {
               if (@_ > 1) {
               print qq~<a href=/?cat=$c><img src="/images/cats_over/$c.jpg" border=0></a>~;
                } else {
               print qq~<img src="/images/cats_over/$c.jpg" border=0>~;
                }
               } else {
               print qq~<img src="/images/cats_over/$c.jpg">~;


              }

        } else {
            print qq~<img src="/images/cats_over/unknown.jpg">~;


           }
        }
        else {
            if ($inlist eq "true") {
              if ($c eq "") {
                print qq~<a href=/?cat=$c><img src="/images/cats/others.jpg" border=0 alt=$c></a>~;


              } else {
               print qq~<a href=/?cat=$c><img src="/images/cats/$c.jpg" border=0 alt=$c></a>~;


              }
        } else {
            print qq~<a href=/?cat=$c><img src="/images/cats/unknown.jpg" border=0 alt=$c></a>~;


        }
           
            }
        }

    print qq~
    </center></td>
  </tr>
</table>~;
    print qq~<table width="100%" border="0" cellspacing="0" cellpadding="0" background="/images/shadow2.jpg" height="4">
  <tr>
    <td width="100%"><img src="/images/shadow2.jpg"></td>
  </tr>
</table>~;


   }

if (@_ > 1 && (!$_[5] || $ENV{'HTTP_WEBMIN_SERVERS'})) {
   # Show tabs under module categories
print '<table width=100% border="0" cellspacing="0" cellpadding="0" background="/images/tabs/bgimage.jpg"><tr><td>';
   
     if ($ENV{'HTTP_WEBMIN_SERVERS'}) {
	&tab_start();
	print "<a href='$ENV{'HTTP_WEBMIN_SERVERS'}'>",
	      "$text{'header_servers'}</a><br>\n";
	&tab_end();
	}
	if (!$_[4]) { &tab_start; print "<a href=\"/$module_name/\">",
			    "$text{'header_module'}</a>"; &tab_end;}
	if (ref($_[2]) eq "ARRAY") {
		&tab_start; print &hlink($text{'header_help'}, $_[2]->[0], $_[2]->[1]); &tab_end;
		}
	elsif (defined($_[2])) {
		&tab_start; 
print &hlink($text{'header_help'}, $_[2]); 
&tab_end;
		}
	if ($_[3]) {
		local %access = &get_module_acl();
		if (!$access{'noconfig'}) {
			&tab_start; print "<a href=\"/config.cgi?$module_name\">",
			      $text{'header_config'},"</a>"; &tab_end;
			}
		}

    foreach $t (split(/<br>/, $_[6])) {
      if ($t =~ /\S/) {
	      &tab_start; print $t; &tab_end;
      }
    }

print "</td></tr></table>";

    if (!$_[5]) {
	    # Show page title in tab
	    local $title = $_[0];
	    $title =~ s/&auml;/ä/g;
	    $title =~ s/&ouml;/ö/g;
	    $title =~ s/&uuml;/ü/g;
	    $title =~ s/&nbsp;/ /g;

#	    print "<p><table border=0 cellpadding=0 cellspacing=0 width=95% align=center><tr><td><table border=0 cellpadding=0 cellspacing=0 height=20><tr>\n";
	    $usercol = defined($gconfig{'cs_header'}) ||
		   defined($gconfig{'cs_table'}) ||
		   defined($gconfig{'cs_page'});
#	    print "<td bgcolor=#bae3ff>",
#	      "<img src=/images/tabs/blue_left.jpg alt=\"\">","</td>\n";
#	    print "<td bgcolor=#bae3ff>&nbsp;<b>$title</b>&nbsp;</td>\n";
#	    print "<td bgcolor=#bae3ff>",
#	      "<img src=/images/tabs/blue_right.jpg alt=\"\">","</td>\n";
#	    print "</tr></table></td></tr></table>"; 

print "<center><font color=#FFFFFF><b>$title</b></font></center>";
&make_sep;
	     &theme_prebody;
	}
    } 
@header_arguments = @_;
}

sub theme_prebody
{
print "<table border=0 width=100% align=center cellspacing=0 cellpadding=0><tr><td background=/images/msctile.jpg>\n";
}

sub theme_postbody
{
print "</table>\n" if (@header_arguments > 1 && !$header_arguments[5]);
}

sub theme_footer {
local $i;

print "</table></table><br>\n"
	if (@header_arguments > 1 && !$header_arguments[5]);

print "<table border=0 width=100% align=center cellspacing=0 cellpadding=0><tr><td>\n";

for($i=0; $i+1<@_; $i+=2) {
    local $url = $_[$i];
    if ($url eq '/') {
        $url = "/?cat=$module_info{'category'}";
        }
    elsif ($url eq '' && $module_name) {
        $url = "/$module_name/";
        }
    elsif ($url =~ /^\?/ && $module_name) {
        $url = "/$module_name/$url";
        }
    if ($i == 0) {
        print "&nbsp;<a href=\"$url\"><img alt=\"<-\" align=middle border=0 src=/images/arrow.jpg></a>\n";
        }
    else {
        print "&nbsp;|\n";
        }
    print "&nbsp;<a href=\"$url\"><font color=#FFFFFF>",&text('main_return', $_[$i+1]),"</font></a>\n";
    }
print "</td></tr></table>\n";

print "<br>\n";
if (!$_[$i]) {
    local $postbody = $tconfig{'postbody'};
    if ($postbody) {
        local $hostname = &get_display_hostname();
        local $version = &get_webmin_version();
        local $os_type = $gconfig{'real_os_type'} ?
                $gconfig{'real_os_type'} : $gconfig{'os_type'};
        local $os_version = $gconfig{'real_os_version'} ?
                $gconfig{'real_os_version'} : $gconfig{'os_version'};
        $postbody =~ s/%HOSTNAME%/$hostname/g;
        $postbody =~ s/%VERSION%/$version/g;
        $postbody =~ s/%USER%/$remote_user/g;
        $postbody =~ s/%OS%/$os_type $os_version/g;
        print "$postbody\n";
        }
    if ($tconfig{'postbodyinclude'}) {
        open(INC, $module_name ?
            "../$gconfig{'theme'}/$tconfig{'postbodyinclude'}" :
            "$gconfig{'theme'}/$tconfig{'postbodyinclude'}");
        while(<INC>) {
            print;
            }
        close(INC);
        }
    if (defined(&theme_postbody)) {
        &theme_postbody(@_);
        }
    print "</body></html>\n";
    }

}

#sub theme_error {

#print "error";

#}


sub chop_font {

if (!$lang->{'titles'} || $gconfig{'texttitles'}) {
	print $t;
} else {
        foreach $l (split(//, $t)) {
            $ll = ord($l);
            if ($ll > 127 && $lang->{'charset'}) {
                print "<img src=/images/letters2/$ll.$lang->{'charset'}.gif alt=\"$l\" align=bottom border=0>";
                }
            elsif ($l eq " ") {
                print "<img src=/images/letters2/$ll.gif alt=\"\&nbsp;\" align=bottom border=0>";
                }
            else {
                print "<img src=/images/letters2/$ll.gif alt=\"$l\" align=bottom border=0>";
                }
            }
	}
}

sub tab_start {
    print qq~    <td nowrap>
      <table border="0" cellspacing="0" cellpadding="0">
        <tr>
          <td background="/images/tabs/bg.jpg"><img src="/images/tabs/left.jpg" nowrap></td>
          <td background="/images/tabs/bg.jpg" nowrap>
          ~;
}


sub tab_end {
     print qq~</td>
          <td background="/images/tabs/bg.jpg" nowrap><img src="/images/tabs/right.jpg"></td>
        </tr>
      </table>

    </td>~;
}

1;

sub make_sep {

print qq~
<table cellpadding="0" cellspacing="0" border="0" width="100%" background="/images/cat_sep.jpg">
    <tr>
    <td valign="Top" width="100%"><img src="/images/left_cat_sep.jpg" alt=" ">
    </td>
    <td valign="Top"><img src="/images/right_cat_sep.jpg" alt=" "></td>
    </tr>
</table>
~;

}
