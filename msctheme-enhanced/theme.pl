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
print "<link rel='icon' href='/images/webmin_icon.png' type='image/png'>\n";
if (@_ > 0) {
    if ($gconfig{'sysinfo'} == 1) {
        printf "<title>%s : %s on %s (%s %s)</title>\n",
            $_[0], $remote_user, &get_system_hostname(),
            $os_type, $os_version;
        }
    else {
        print "<title>$_[0]</title>\n";
        }
    print $_[7] if ($_[7]);
    if ($gconfig{'sysinfo'} == 0 && $remote_user) {
        print "<SCRIPT LANGUAGE=\"JavaScript\">\n";
        printf
        "defaultStatus=\"%s%s logged into %s %s on %s (%s %s)\";\n",
            $ENV{'ANONYMOUS_USER'} ? "Anonymous user" : $remote_user,
            $ENV{'SSL_USER'} ? " (SSL certified)" :
            $ENV{'LOCAL_USER'} ? " (Local user)" : "",
	    $text{'programname'},
            &get_webmin_version(), &get_system_hostname(),
            $os_type, $os_version;

#########JAVA & CSS FOR MENUS START###########
print qq~
   var r;
   var menuLive;
   var shouldSet;
   var image_name;
   var image_over;
   var image_out;

   function showMenu(cat) {
     if (menuLive) {
       if (r) {
           r.style.display='none'
       }
       r = document.getElementById(cat)
       r.style.display=''
     }
   }

   function setLive() {
       if (menuLive) {
          menuLive ='' 
          hideMenu()
       } else {
          menuLive = '1'
       }
   }

   function hideMenu() {
      if (r) {
         r.style.display='none'
      }
   }

 
   function mouseover(image_name, image_over) {
      this.document[image_name].src= image_over;
   }
 
   function mouseout(image_name, image_out) {
      this.document[image_name].src=image_out;
   }


</script>
                                                                                
<style type="text/css">
div.menucontainer {
    padding: 2px 2px;
    border: 1px groove gray;
    background: lightgrey;
    border-width: 2px;
    position: absolute;
}

div.menu a  {
    font: 1em sans-serif;
    text-decoration: none;
}

div.menu {
    border-bottom: 1px solid silver;
}

div.menu div:hover {
    color: white;
    background: grey;
}


div.title_menu {
    border-bottom: 1px solid silver;
    font: 1em sans-serif;
    list-style-type: none;
    background: black;
    color: white;
    font-weight: bold;
}

</style>
~;
#########JAVA & CSS FOR MENUS STOP###########

        }
    }

@msc_modules = &get_available_module_infos()
	if (!length(@msc_modules));

print "</head>\n";
if ($theme_no_table) {
	print '<body bgcolor=#6696bc link=#000000 vlink=#000000 text=#000000 leftmargin="0" topmargin="0" marginwidth="0" marginheight="0" '.$_[8].'>';
	}
else {
	print '<body bgcolor=#6696bc link=#000000 vlink=#000000 text=#000000 leftmargin="0" topmargin="0" marginwidth="0" marginheight="0" '.$_[8].'>';
	}

if ($remote_user && @_ > 1) {
	# Show basic header with webmin.com link and logout button
	local $logout = $main::session_id ? "/session_login.cgi?logout=1"
					  : "/switch_user.cgi";
	local $loicon = $main::session_id ? "logout.jpg" : "switch.jpg";
	local $lowidth = $main::session_id ? 84 : 27;
	local $lotext = $main::session_id ? $text{'main_logout'}
					  : $text{'main_switch'};
	print qq~
          <table width="100%" border="0" cellspacing="0" cellpadding="0" background="/images/top_bar/bg.jpg" height="32">
	  <tr>
	    <td width="4" nowrap><img src="/images/top_bar/left.jpg" width="4" height="32"></td>
	    <td width="100%" nowrap><a href="http://www.webmin.com"><img src="/images/top_bar/webmin_logo.jpg" width="99" height="32" border="0" alt="Webmin home page"></a></td>~;
	if (!$ENV{'ANONYMOUS_USER'}) {
		if ($gconfig{'nofeedbackcc'} != 2 && $gaccess{'feedback'}) {
			print qq~<td><a href='/feedback_form.cgi?module=$module_name'><img src=/images/top_bar/feedback.jpg width=97 height=32 alt="$text{'main_feedback'}" border=0></a></td>~;
			}
		if (!$ENV{'SSL_USER'} && !$ENV{'LOCAL_USER'} &&
		    !$ENV{'HTTP_WEBMIN_SERVERS'}) {
			if ($gconfig{'nofeedbackcc'} != 2 &&
			    $gaccess{'feedback'}) {
				print qq~<td><img src=/images/top_bar/top_sep.jpg width=12 height=32></td>~;
				}
			print qq~<td width="84" nowrap><a href='$logout'><img src="/images/top_bar/$loicon" height="31" width=$lowidth border="0" alt="$lotext"></a></td>~;
			}
		}
	print qq~<td width="3" nowrap>
	      <div align="right"><img src="/images/top_bar/right.jpg" width="3" height="32"></div>
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
    <td background="/images/top_bar/shadow_bg.jpg" nowrap><img src="/images/top_bar/shadow.jpg" width="8" height="7"></td>
  </tr>
</table>~;

    local %catnames;
    &read_file("$config_directory/webmin.catnames", \%catnames);
    foreach $m (@msc_modules) {
        local $c = $m->{'category'};
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

    if ($theme_index_page) {
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
    print qq~<table width="100%" border="0" cellspacing="0" cellpadding="0" height="57" background="/images/nav/bg.jpg">
  <tr background="/images/nav/bg.jpg">
    <td width="6" nowrap><img src="/images/nav/left.jpg" width="3" height="57"></td>~;

    foreach $c (@cats) {
        local $t = $cats{$c};
           $inlist    = "false";
           foreach $testet (@available) {
               if ($testet eq $c) {
                $inlist = "true";
               } 
            }
        if ($in{'cat'} eq $c && $theme_index_page) {
           if ($inlist eq "true") {

              if ($c eq "") {

###OTHER MENU [ACTIVE]

                print qq~<td nowrap><center><a href="/?cat=" onMouseOver="showMenu('other_menu');"><img src="/images/cats/other_over.jpg" alt="$t" width="43" height="44" border="0" name="other_image"></a><img src="/images/list.gif" width="10" height="44" border="0" onClick="setLive(); showMenu('other_menu');" onMouseOver="showMenu('other_menu');"><br><a href="/?cat=" onMouseOver="showMenu('other_menu');">~;

            &chop_font;

                print "</a></center>";
&create_menu();
                print qq~</td>
    <td width="17" nowrap><img src="/images/nav/sep.jpg" width="17" height="57"></td>~; 
              } elsif ($c eq "webmin") {

###WEBMIN MENU [ACTIVE]

               if (@_ > 1) {
                print qq~<td nowrap><center><a href="/?cat=$c" onMouseOver="if (menuLive) showMenu('$c\_menu');"><img src="/images/cats/$c\_over.jpg" alt="$t" width="43" height="44" border="0"></a><img src="/images/list.gif" width="10" height="44" border="0" onClick="setLive(); showMenu('$c\_menu');" onMouseOver="if (menuLive) showMenu('$c\_menu');"><a href="/?cat=$c" onMouseOver="if (menuLive) showMenu('$c\_menu');"><br>~;


            &chop_font;
                          print "</a></center>";
&create_menu();
                          print qq~</td>
    <td width="17" nowrap><img src="/images/nav/sep.jpg" width="17" height="57"></td>~;
                } else {

###UNKNOWN MENU [ACTIVE]

                print qq~<td nowrap><center><a href="/?cat=$c" onMouseOver="if (menuLive) showMenu('$c\_menu');"><img src="/images/cats/unknown_over.jpg" alt="$t" width="43" height="44" border="0"></a><img src="/images/list.gif" width="10" height="44" border="0" onClick="setLive(); showMenu('$c\_menu');" onMouseOver="if (menuLive) showMenu('$c\_menu');"><a href="/?cat=$c" onMouseOver="if (menuLive) showMenu('$c\_menu');"><br>~;
                     &chop_font;
                     print "</a></center>";
&create_menu();
                     print qq~</td>
    <td width="17" nowrap><img src="/images/nav/sep.jpg" width="17" height="57"></td>~;
                }
               } else {

###REST OF MENUS [ACTIVE]

                print qq~<td nowrap><center><a href="/?cat=$c" onMouseOver="if (menuLive) showMenu('$c\_menu');"><img src="/images/cats/$c\_over.jpg" alt="$t" width="43" height="44" border="0"></a><img src="/images/list.gif" width="10" height="44" border="0" onClick="setLive(); showMenu('$c\_menu');" onMouseOver="if (menuLive) showMenu('$c\_menu');"><a href="/?cat=$c" onMouseOver="if (menuLive) showMenu('$c\_menu');"><br>~;

            &chop_font;

               print "</a></center>";
&create_menu();
               print qq~</td>
    <td width="17" nowrap><img src="/images/nav/sep.jpg" width="17" height="57"></td>~;
              }

        } else {

###UNKNOWN CATAGORY [ACTIVE]

                print qq~<td nowrap><center><a href="/?cat=$c" onMouseOver="if (menuLive) showMenu('$c\_menu');"><img src="/images/cats/unknown_over.jpg" alt="$t" width="43" height="44" border="0"></a><img src="/images/list.gif" width="10" height="44" border="0" onClick="setLive(); showMenu('$c\_menu');" onMouseOver="if (menuLive) showMenu('$c\_menu');"><a href="/?cat=$c" onMouseOver="if (menuLive) showMenu('$c\_menu');"><br>~;

            &chop_font;

            print "</a></center>";
&create_menu();
            print qq~</td>
    <td width="17" nowrap><img src="/images/nav/sep.jpg" width="17" height="57"></td>~;
           }
        }
        else {
            if ($inlist eq "true") {
              if ($c eq "") {

###OTHER MENU [NON-ACTIVE]

                print qq~<td nowrap><center><a href="/?cat=" onMouseOver="showMenu('other_menu'); mouseover('other_image','/images/cats/other_over.jpg');" onMouseOut="mouseout('other_image','/images/cats/other.jpg');"><img src="/images/cats/other.jpg" alt="$t" width="43" height="44" border="0" name="other_image"></a><img src="/images/list.gif" width="10" height="44" border="0" onClick="setLive(); showMenu('other_menu');" onMouseOver="showMenu('other_menu'); mouseover('other_image','/images/cats/other_over.jpg');" onMouseOut="mouseout('other_image','/images/cats/other.jpg');"><a href="/?cat=" onMouseOver="showMenu('other_menu'); mouseover('other_image','/images/cats/other_over.jpg');" onMouseOut="mouseout('other_image','/images/cats/other.jpg');"><br>~;


            &chop_font;

                print "</a></center>";
&create_menu();
                print qq~</td>
    <td width="17" nowrap><img src="/images/nav/sep.jpg" width="17" height="57"></td>~; 
              } else {

###REST OF MENUS [NON-ACTIVE]
                print qq~<td nowrap><center><a href="/?cat=$c" onMouseOver="if (menuLive) showMenu('$c\_menu'); mouseover('$c\_image','/images/cats/$c\_over.jpg');" onMouseOut="mouseout('$c\_image','/images/cats/$c.jpg');"><img src="/images/cats/$c.jpg" alt="$t" width="43" height="44" border="0" name="$c\_image"></a><img src="/images/list.gif" width="10" height="44" border="0" onClick="setLive(); showMenu('$c\_menu');" onMouseOver="if (menuLive) showMenu('$c\_menu'); mouseover('$c\_image','/images/cats/$c\_over.jpg');" onMouseOut="mouseout('$c\_image','/images/cats/$c.jpg');"><a href="/?cat=$c" onMouseOver="if (menuLive) showMenu('$c\_menu'); mouseover('$c\_image','/images/cats/$c\_over.jpg');" onMouseOut="mouseout('$c\_image','/images/cats/$c.jpg');"><br>~;


            &chop_font;

               print "</a></center>";
&create_menu();
               print qq~</td>
    <td width="17" nowrap><img src="/images/nav/sep.jpg" width="17" height="57"></td>~;
              }
        } else {

###UNKNOWN CATAGORY [NON-ACTIVE]

                print qq~<td nowrap><center><a href="/?cat=$c" onMouseOver="if (menuLive) showMenu('$c\_menu'); mouseover('$c\_image','/images/cats/unknown_over.jpg');" onMouseOut="mouseout('$c\_image','/images/cats/unknown.jpg');"><img src="/images/cats/unknown.jpg" alt="$t" width="43" height="44" border="0" name="$c\_image"></a><img src="/images/list.gif" width="10" height="44" border="0" onClick="setLive(); showMenu('$c\_menu');" onMouseOver="if (menuLive) showMenu('$c\_menu'); mouseover('$c\_image','/images/cats/unknown_over.jpg');" onMouseOut="mouseout('$c\_image','/images/cats/unknown.jpg');"><a href="/?cat=$c" onMouseOver="if (menuLive) showMenu('$c\_menu'); mouseover('$c\_image','/images/cats/unknown_over.jpg');" onMouseOut="mouseout('$c\_image','/images/cats/unknown.jpg');"><br>~;

            &chop_font;

            print "</a></center>";
&create_menu();
            print qq~</td>
    <td width="17" nowrap><img src="/images/nav/sep.jpg" width="17" height="57"></td>~;
        }
           
            }
        }

    print qq~<td width="100%" nowrap><div onClick="hideMenu(); if (menuLive) setLive();">&nbsp;</td>
    <td nowrap>&nbsp;</td>
  </tr>
</table>~;
    print qq~<div onClick="hideMenu(); if (menuLive) setLive();"><table width="100%" border="0" cellspacing="0" cellpadding="0" background="/images/nav/bottom_bg.jpg" height="4">
  <tr>
    <td width="100%"><img src="/images/nav/bottom_left.jpg" width="3" height="4"></td>
  </tr>
</table>~;
   }

if (@_ > 1 && (!$_[5] || $ENV{'HTTP_WEBMIN_SERVERS'})) {
   # Show tabs under module categories
   print qq~<table width="100%" border="0" cellspacing="0" cellpadding="0" background="/images/nav/bottom_shadow2.jpg"> <tr background="/images/nav/bottom_shadow2.jpg">~;

   if ($gconfig{'sysinfo'} == 2 && $remote_user) {
	&tab_start();
	printf "%s%s logged into %s %s on %s (%s%s)</td>\n",
		$ENV{'ANONYMOUS_USER'} ? "Anonymous user" : "<tt>$remote_user</tt>",
		$ENV{'SSL_USER'} ? " (SSL certified)" :
		$ENV{'LOCAL_USER'} ? " (Local user)" : "",
		$text{'programname'},
		$version, "<tt>".&get_system_hostname()."</tt>",
		$os_type, $os_version eq "*" ? "" : " $os_version";
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
		local $mi = $module_index_link ||
			    $module_name ? "/$module_name/" : "/";
		&tab_start; print "<a href=\"$gconfig{'webprefix'}$mi\">",
			    "$text{'header_module'}</a>"; &tab_end;
		}
	if (ref($_[2]) eq "ARRAY" && !$ENV{'ANONYMOUS_USER'}) {
		&tab_start; print &hlink($text{'header_help'}, $_[2]->[0], $_[2]->[1]); &tab_end;
		}
	elsif (defined($_[2]) && !$ENV{'ANONYMOUS_USER'}) {
		&tab_start; print &hlink($text{'header_help'}, $_[2]); &tab_end;
		}
	if ($_[3]) {
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

print qq~
    <td nowrap width="100%" background="/images/nav/bottom_shadow2.jpg" valign="top">

      <table width="100%" border="0" cellspacing="0" cellpadding="0" background="/images/nav/bottom_shadow2.jpg">
        <tr>
          <td><img src="/unauthenticated/nav/bottom_shadow.jpg" width="43" height="9"></td>
        </tr>
      </table>


    </td>
  </tr>
</table>~;

    if (!$_[5]) {
	    # Show page title in tab
	    local $title = $_[0];
	    $title =~ s/&auml;/ä/g;
	    $title =~ s/&ouml;/ö/g;
	    $title =~ s/&uuml;/ü/g;
	    $title =~ s/&nbsp;/ /g;

	    print "<p><table border=0 cellpadding=0 cellspacing=0 width=95% align=center><tr><td><table border=0 cellpadding=0 cellspacing=0 height=20><tr>\n";
	    print "<td bgcolor=#bae3ff>",
	      "<img src=/images/tabs/blue_left.jpg width=13 height=22 ",
	      "alt=\"\">","</td>\n";
	    print "<td bgcolor=#bae3ff>&nbsp;<b>$title</b>&nbsp;</td>\n";
	    print "<td bgcolor=#bae3ff>",
	      "<img src=/images/tabs/blue_right.jpg width=19 height=22 ",
	      "alt=\"\">","</td>\n";
	    if ($_[9]) {
		print "</tr></table></td> <td align=right><table border=0 cellpadding=0 cellspacing=0 height=20><tr>\n";
		print "<td bgcolor=#bae3ff>",
		      "<img src=/images/tabs/blue_left.jpg width=13 height=22 ",
		      "alt=\"\">","</td>\n";
		print "<td bgcolor=#bae3ff>&nbsp;<b>$_[9]</b>&nbsp;</td>\n";
		print "<td bgcolor=#bae3ff>",
		      "<img src=/images/tabs/blue_right.jpg width=19 height=22",
		      " alt=\"\">","</td>\n";
		}
	    print "</tr></table></td></tr></table>"; 

	     &theme_prebody;
	}
    } elsif (@_ > 1) {
	    print qq~<table width="100%" border="0" cellspacing="0" cellpadding="0" background="/unauthenticated/nav/bottom_shadow.jpg">
	  <tr>
	    <td width="100%" nowrap><img src="/unauthenticated/nav/bottom_shadow.jpg" width="43" height="9"></td>
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
	#print "<table border=0 width=95% align=center cellspacing=0 cellpadding=0><tr><td background=/images/msctile2.jpg>\n";
	print "<table border=0 width=95% align=center cellspacing=0 cellpadding=0><tr><td bgcolor=#ffffff>\n";
	print "<table border=0 width=95% align=center cellspacing=0 cellpadding=0><tr><td>\n";
	}
}

sub theme_footer {
local $i;

if ($theme_no_table) {
	print "</ul>\n";
	}
elsif (@header_arguments > 1 && !$header_arguments[5]) {
	print "</table></table><br>\n";
	}

print "<table border=0 width=100% align=center cellspacing=0 cellpadding=0 bgcolor=#6696bc><tr><td>\n";

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
    print "&nbsp;<a href=\"$url\">",&text('main_return', $_[$i+1]),"</a>\n";
    }
print "</td></tr></table>\n";

print "<br>\n";
if (!$_[$i]) {
    local $postbody = $tconfig{'postbody'};
    if ($postbody) {
        local $hostname = &get_system_hostname();
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
    print "</div></body></html>\n";
    }

}

#sub theme_error {

#print "error";

#}


sub chop_font {

if (!$current_lang_info->{'titles'} || $gconfig{'texttitles'}) {
	print $t;
} else {
        foreach $l (split(//, $t)) {
            $ll = ord($l);
	    local $gif;
            if ($ll > 127 && $current_lang_info->{'charset'}) {
		$gif = "$ll.$current_lang_info->{'charset'}.gif";
		}
	    else {
		$gif = "$ll.gif";
		}
	    local $sz = $letter_sizes{$gif};
	    printf "<img src=/images/letters2/%s width=%d height=%d alt=\"%s\" align=bottom border=0>",
		$gif, $sz->[0], $sz->[1], $ll eq " " ? "&nbsp;" : $l;
            }
	}
}

sub tab_start {
    print qq~    <td nowrap>
      <table border="0" cellspacing="0" cellpadding="0">
        <tr>
          <td background="/images/tabs/bg.jpg"><img src="/images/tabs/left.jpg" width="12" height="21" nowrap></td>
          <td background="/images/tabs/bg.jpg" nowrap>
          ~;
}


sub tab_end {
     print qq~</td>
          <td background="/images/tabs/bg.jpg" nowrap><img src="/images/tabs/right.jpg" width="15" height="21"></td>
        </tr>
        <tr>
          <td nowrap><img src="/images/tabs/right_bottom.jpg" width="12" height="4"></td>
          <td background="/images/tabs/bottom.jpg" nowrap><img src="/images/tabs/bottom.jpg" width="17" height="4"></td>
          <td nowrap><img src="/images/tabs/left_bottom.jpg" width="15" height="4"></td>        </tr>
      </table>

    </td>~;
}

sub create_menu {
   my $tmpid;
   if ($c eq "") { $tmpid = "other"; }
   else { $tmpid = $c; }

   my $tmpimg;
   if ($c eq "") { $tmpimg = "other"; }
   if ($inlist eq "true" && $c ne "") { $tmpimg = "$c"; }
   if ($inlist ne "true" && $c ne "") { $tmpimg = "unknown"; }

   if ($in{'cat'} eq $c) {
      print qq~
         <div id="$tmpid\_menu" class="menucontainer" style="display:none" align="left">
         <div id="$tmpid\_menu" class="title_menu"><center>$t</center></a></div>
      ~;
   } else {
      print qq~
         <div id="$tmpid\_menu" class="menucontainer" style="display:none" align="left" onMouseOver="mouseover('$tmpid\_image','/images/cats/$tmpimg\_over.jpg');" onMouseOut="mouseout('$tmpid\_image','/images/cats/$tmpimg.jpg');">
         <div id="$tmpid\_menu" class="title_menu"><center>$t</center></a></div>
      ~;
   }

   foreach $m (@msc_modules) {
      next if ($m->{'category'} ne $c);
      print "<div id=\"$tmpid\_menu\" class=\"menu\">";
      print "<a href=/$m->{'dir'}/>";
      print "<div id=\"$tmpid\_menu\">";
      print "<img src=\"/$m->{'dir'}/images/icon.gif\" width=\"20\" height=\"20\" border=\"0\"> $m->{'desc'}";
      print "</div></a></div>";
   }

   print "</div>";
}

1;

