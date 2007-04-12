#javascript-lib.pl

#------------------------------#
#  JavaScript Library          #
#                              #
#  Written By:                 #
#    John Smith                #
#    <john.smith@msclinux.com> #
#                              #
#  MSC.Software                #
#  http://www.msclinux.com     #
#  http://www.mscsoftware.com  #
#------------------------------#

#----------------------------------------------------------------------------#
# Available Functions                                                        #
#    *jroll_over                                                             #
#      -This gives you simple mouse over functions on graphics               #
#       and includea a link.                                                 #
#       -Usage = &jroll_over("url", "name", "border", "imgoff", "imgon");    #
#    *jimg_preload                                                           #
#      -Preloads any number of given images.                                 #
#       -Usage = &jimg_preload("image/1.gif", "imgage/u.gif");               #
#    *jimg_update                                                            #
#      -Updates any image on your page that has a name                       #
#       -Usage = &jimg_update("imgname", "image/toload.gif");                #
#    *janim                                                                  #
#      -Builds an Animation with any given list of images                    #
#       -Usage = &janim("name", "speed", "list.gif", "of.gif", "images.jpg") #
#    *janim_start                                                            #
#      -Starts the animation you built with janim                            #
#       -Usage = &janim_start("name");                                       #
#    *janim_stop                                                             #
#      -Stops the animation you built with janim                             #
#       -Usage = &janim_stop("name");                                        #
#    *jalert                                                                 #
#      -Launches an alert dialog box with a custom message                   #
#       -Usage = &jalert("Your alert message!");                             #
#    *jwindow                                                                #
#      -Opens a window with a given URL                                      #
#       -Usage = &jwindow("url", "name", "width", "height");                 #
#    *jwindow_xy                                                             #
#      -Repostitions a named windows x and y                                 #
#       -Usage = &jwindow_xy("name", "x", "y");                              #
#    *jterminal                                                              #
#      -Creates an empty plain text window for writing data to               #
#       -Usage = &jterminal("name", "width", "height");                      #
#    *jwrite                                                                 #
#      -Write data to a created window or terminal                           #
#       -Usage = &jwrite("name", "data to write");                           #
#    *jtext                                                                  #
#      -Simple text rollovers between two colors                             #
#       -Usage = &jtext("text message", "red", "#F1F1F1");                   #
#    *jtalkback                                                              #
#      -Builds a JavaScript for a pop-up talkback/bug report window          #
#       -Usage = &jtalkback();                                               #
#    *jerror                                                                 #
#      -Launches the jtalkback window upon execution                         #
#       -Usage = &jerror("title", "email", "width", "height", \              #
#                        "errmsg", "url", "erroredonline");                  #
#    *jtalkback_link                                                         #
#      -Creates a button or text link to launch the jtalkback window         #
#       -Usage = &jtalkback_link("title", "email", "width", "height", \      #
#                                "text", "type");                            #
#----------------------------------------------------------------------------#

#creates a mouse over event with a link
sub jroll_over {
   my ($url, $name, $border, $img_off, $img_on) = @_;
   if (!$url) { $url = "javascript:"; }
   print "\n<a href=\"$url\"", " onmouseover=\"document.$name.src=\'$img_on\'\;\"", " onmouseout=\"document.$name.src=\'$img_off\'\;\">";
   print "<img src=\"$img_off\" name=\"$name\" border=\"0\" alt=\"$name\"></a>";
}

#preloads a list of images for smooth loading
sub jimg_preload {
   my (@img_array) = @_; 
   print "<SCRIPT LANGUAGE=JavaScript>\n";
   foreach my $img (@img_array) {
      print "(new Image).src = \"$img\"\;\n";
   }
   print "</SCRIPT>\n";
}

#update any image on a page by its name
sub jimg_update {
   my ($name, $img) = @_;
   print "<SCRIPT LANGUAGE=JavaScript>\n";
   print "document.$name.src = '$img';\n";
   print "</SCRIPT>\n";
}

#build an animation (preloads images itself)
sub janim {
   my ($name, $speed, @anim_array) = @_;
   my $frames = @anim_array;
   my $count = 0;
   my $arraycount = 0;
   print "<img name='$name' src='@anim_array[0]' alt='$name'>\n";
   print "<SCRIPT LANGUAGE=JavaScript>\n";
   print "var aniframes$name = new Array($frames);\n";
   foreach my $img (@anim_array) {
      print "aniframes$name\[$count] = new Image();\n";
      print "aniframes$name\[$count].src = '@anim_array[$arraycount]';\n";
      $arraycount++;
      $count++;
   }
   print "var frame$name = 0;\n";
   print "var timeout_id$name = null;\n";
   print "function animate$name() {\n";
   print "document.$name.src = aniframes$name\[frame$name].src;\n";
   print "frame$name = (frame$name + 1)%$frames;\n";
   print "timeout_id$name = setTimeout('animate$name()', $speed);\n";
   print "}\n";
   print "</SCRIPT>\n";
}

#start an animation
sub janim_start {
   my ($name) = @_;
   print "<SCRIPT LANGUAGE=JavaScript>\n";
   print "animate$name();\n";
   print "</SCRIPT>\n";
}

#stop an animation
sub janim_stop {
   my ($name, $image) = @_;
   if (!$image) { }
   print "<SCRIPT LANGUAGE=JavaScript>\n";
   print "if (timeout_id$name) clearTimeout(timeout_id$name);\n";
   print "timeout_id$name=null;\n";
   if ($image) {
      print "document.$name.src = '$image';\n";
   }
   print "</SCRIPT>\n";
}

#create an alert dialog box
sub jalert {
   my (@alert_msg) = @_;
   print "<SCRIPT LANGUAGE=JavaScript>\n";
   print "alert('@alert_msg')";
   print "</SCRIPT>\n";
}

#opens a specified url in a seprate window
sub jwindow {
   my ($url, $name, $width, $height) = @_;
   if (!$width)  { $width  = "300"; }
   if (!$height) { $height = "200"; }
   print "<SCRIPT LANGUAGE=JavaScript>\n";
   print "$name = window.open('$url','$name','width=$width,height=$height');\n";
   print "</SCRIPT>\n";
}

#sets a specified window to x y location
sub jwindow_xy {
   my ($name, $x, $y) = @_;
   print "<SCRIPT LANGUAGE=JavaScript>\n";
   print "$name.moveTo('$x','$y');\n";
   print "</SCRIPT>\n";
}

#opens a blank terminal window for writing data to
sub jterminal {
   my ($name, $width, $height) = @_;
   if (!$width)  { $width  = "300"; }
   if (!$height) { $height = "200"; }
   print "<SCRIPT LANGUAGE=JavaScript>\n";
   print "$name = window.open('','$name','width=$width,height=$height');\n";
   print "$name.document.open('text/plain')\n";
   print "</SCRIPT>\n";
}

#write data to a given window name
sub jwrite {
   my ($name, @msg) = @_;
   print "<SCRIPT LANGUAGE=JavaScript>\n";
   print "$name.document.writeln('@msg');\n";
   print "</SCRIPT>\n";
}

#text rollover
sub jtext {
   my ($text, $coloroff, $coloron) = @_;
   print "<font color=\"$coloroff\" onMouseOver=\"this.style.color = '$coloron'\" onMouseOut=\"this.style.color = '$coloroff'\">$text</font>";
}

#Puts the needed JavaScript into your page for talkback reports
sub jtalkback {
   print "<SCRIPT LANGUAGE=JavaScript>\n";
   print "var error_count = 0;\n";

   print "function talkback(title,email,width,height,errmsg,url,line)\n";
   print "{\n";
   print "   var w = window.open(\"\", \"error\"+error_count++, \"resizable,status,width=\"+ width + \",height=\" + height + \"\");\n";
   print "   var d = w.document;\n";
   print "d.write('<body bgcolor=\"#FFFFFF\" text=\"#000000\" leftmargin=\"0\" topmargin=\"0\" marginwidth=\"0\" marginheight=\"0\">');\n";

   print "d.write('<form action=\"/jtalkback.cgi\" method=\"post\">');\n";

   print "d.write('<input type=\"hidden\" name=\"Subject\" value=\"' + title + '\">');\n";  
   print "d.write('<input type=\"hidden\" name=\"EmailTo\" value=\"' + email + '\">');\n";  

   print "d.write('<table width=\"100%\" border=\"1\" cellspacing=\"0\" cellpadding=\"2\">');\n";
   print "d.write('  <tr $tb>');\n";
   print "d.write('    <td colspan=\"2\">');\n";
   print "d.write('      <div align=\"center\"><font size=\"4\" face=\"Verdana, Arial, Helvetica, sans-serif\">' + title + '</font></div>');\n";
   print "d.write('    </td>');\n";
   print "d.write('  </tr>');\n";


   print "d.write('  <tr $cb>');\n";
   print "d.write('    <td width=\"18%\">');\n";
   print "d.write('      <div align=\"right\"><font face=\"Verdana, Arial, Helvetica, sans-serif\"><b>Name:</b>');\n";
   print "d.write('        </font></div>');\n";
   print "d.write('    </td>');\n";
   print "d.write('    <td width=\"82%\"> <font face=\"Verdana, Arial, Helvetica, sans-serif\">');\n";
   print "d.write('<center><input size=\"42\" name=\"Name\"></center>');\n";
   print "d.write('      </font></td>');\n";
   print "d.write('  </tr>');\n";

   print "d.write('  <tr $cb>');\n";
   print "d.write('    <td width=\"18%\">');\n";
   print "d.write('      <div align=\"right\"><font face=\"Verdana, Arial, Helvetica, sans-serif\"><b>eMail:</b>');\n";
   print "d.write('        </font></div>');\n";
   print "d.write('    </td>');\n";
   print "d.write('    <td width=\"82%\"> <font face=\"Verdana, Arial, Helvetica, sans-serif\">');\n";
   print "d.write('<center><input size=\"42\" name=\"eMail\"></center>');\n";
   print "d.write('      </font></td>');\n";
   print "d.write('  </tr>');\n";


   print "d.write('  <tr $cb>');\n";
   print "d.write('    <td width=\"18%\">');\n";
   print "d.write('      <div align=\"right\"><font face=\"Verdana, Arial, Helvetica, sans-serif\"><b>OS:</b>');\n";
   print "d.write('        </font></div>');\n";
   print "d.write('    </td>');\n";
   print "d.write('    <td width=\"82%\"> <font face=\"Verdana, Arial, Helvetica, sans-serif\">');\n";
   print "d.write('<center><input size=\"42\" name=\"OS\"></center>');\n";
   print "d.write('      </font></td>');\n";
   print "d.write('  </tr>');\n";

   print "d.write('  <tr $cb>');\n";
   print "d.write('    <td width=\"18%\">');\n";
   print "d.write('      <div align=\"right\"><font face=\"Verdana, Arial, Helvetica, sans-serif\"><b>Program:</b>');\n";
   print "d.write('        </font></div>');\n";
   print "d.write('    </td>');\n";
   print "d.write('    <td width=\"82%\"> <font face=\"Verdana, Arial, Helvetica, sans-serif\">');\n";
   print "d.write('<center><input size=\"42\" name=\"Program\" value=\"' + url + '\"></center>');\n";
   print "d.write('      </font></td>');\n";
   print "d.write('  </tr>');\n";


   print "d.write('  <tr $cb>');\n";
   print "d.write('    <td width=\"18%\">');\n";
   print "d.write('      <div align=\"right\"><font face=\"Verdana, Arial, Helvetica, sans-serif\"><b>Error:</b>');\n";
   print "d.write('        </font></div>');\n";
   print "d.write('    </td>');\n";
   print "d.write('    <td width=\"82%\"> <font face=\"Verdana, Arial, Helvetica, sans-serif\">');\n";
   print "d.write('<center><input size=\"42\" name=\"Error\" value=\"' + errmsg + '\"></center>');\n";
   print "d.write('      </font></td>');\n";
   print "d.write('  </tr>');\n";

   print "d.write('  <tr $cb>');\n";
   print "d.write('    <td width=\"18%\">');\n";
   print "d.write('      <div align=\"right\"><font face=\"Verdana, Arial, Helvetica, sans-serif\"><b>Line:</b>');\n";
   print "d.write('        </font></div>');\n";
   print "d.write('    </td>');\n";
   print "d.write('    <td width=\"82%\"> <font face=\"Verdana, Arial, Helvetica, sans-serif\">');\n";
   print "d.write('<center><input size=\"42\" name=\"Line\" value=\"' + line + '\"></center>');\n";
   print "d.write('      </font></td>');\n";
   print "d.write('  </tr>');\n";

   print "d.write('  <tr $cb>');\n";
   print "d.write('    <td width=\"18%\">');\n";
   print "d.write('      <div align=\"right\"><font face=\"Verdana, Arial, Helvetica, sans-serif\"><b>Browser:</b>');\n";
   print "d.write('        </font></div>');\n";
   print "d.write('    </td>');\n";
   print "d.write('    <td width=\"82%\"> <font face=\"Verdana, Arial, Helvetica, sans-serif\">');\n";
   print "d.write('<center><input size=\"42\" name=\"Browser\" value=\"' + navigator.userAgent + '\"></center>');\n";
   print "d.write('      </font></td>');\n";
   print "d.write('  </tr>');\n";

   print "d.write('  <tr $cb>');\n";
   print "d.write('    <td width=\"18%\">');\n";
   print "d.write('      <div align=\"right\"><font face=\"Verdana, Arial, Helvetica, sans-serif\"><b>Comment:</b>');\n";
   print "d.write('        </font></div>');\n";
   print "d.write('    </td>');\n";
   print "d.write('    <td width=\"82%\"> <font face=\"Verdana, Arial, Helvetica, sans-serif\">');\n";
   print "d.write('<center><input size=\"42\" name=\"Comment\"></center>');\n";
   print "d.write('      </font></td>');\n";
   print "d.write('  </tr>');\n";
   print "d.write('  </table>');\n";

   print "d.write('<table border=\"0\" width=\"100%\"><tr><td>');\n";
   print "d.write('      <input type=\"submit\" value=\"Report Error\">&nbsp;&nbsp;');\n";
   print "d.write('      <input type=\"button\" value=\"Dismiss\" onclick=\"self.close();\">');\n";
   print "d.write('</td></tr></table>');\n";

   print "d.write('</form>');\n";
   print "d.close();\n";
   print "return true;\n";
   print "}\n";
   print "</SCRIPT>\n";

}

#Launches the talkback form
sub jerror {
   my ($title, $email, $width, $height, $errmsg, $url, $line) = @_;
   print "<SCRIPT LANGUAGE=JavaScript>\n";
   print "talkback('$title','$email','$width','$height','$errmsg','$url','$line');\n";
   print "</SCRIPT>\n";
}

#Allows you to manually luanch the talkback form
sub jtalkback_link {
   my ($title, $email, $width, $height, $text, $type) = @_;
   if ($type eq 0) {
      print "<a href=\"#\" onclick=\"talkback('$title', '$email', '$width', '$height','$errmsg','$url','$line');\">$text</a>\n";
   } elsif ($type eq 1) {
      print "<form><input type=\"button\" value=\"$text\" onclick=\"talkback('$title', '$email', '$width', '$height','$errmsg','$url','$line');\"></form>\n";
   }
}

return 1;
