#!/usr/local/bin/perl
# index.cgi
# Display the shell-in-a-box pages

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

chop($hw = `uname -m`);
$hw =~ /(86|x86_64)$/ || &error($text{'index_ecpu'});
system("chmod 6755 cgi-bin/shellinabox.data/shellinaboxd");
system("rm -f cgi-bin/shellinabox.data/shellinabox.socket");

&PrintHeader();
print <<EOF;
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
<html>
  <head>
    <title>Welcome to Shell-In-A-Box</title>
  </head>
  <frameset rows="*,0" border=0>
    <frame src=applet.html name=applet noresize scrolling=no border=no marginwidth=0 marginheight=0>
    <frame src=blank.html name=hidden noresize scrolling=no border=no marginwidth=0 marginheight=0>
  </frameset>
  <noframes>
    <body bgcolor=#c0c0c0>
      <center>
        <script language=JavaScript1.2>
        <!--
        document.writeln("<applet code='com/shellinabox/ShellInABox.class'");
        document.writeln("        align=center alt='ShellInABox' name='ShellInABox'");
        if (typeof innerWidth == "undefined") {
          document.writeln("        width='100%' height='100%'");
        } else {
          document.writeln("        width='" + innerWidth + "' height='" + innerHeight + "'");
        }
        document.writeln("        hiddenframe=''");
        document.writeln("  <param name=hiddenframe value=''>");
        document.writeln("</applet>");
        //-->
        </script>
        <noscript>
        <applet code='com/shellinabox/ShellInABox.class'
                align=center alt='ShellInABox' name='ShellInABox'
                width='100%' height='100%'
                hiddenframe=''>
          <param name=hiddenframe value=''>
        </applet>
        </noscript>
      <center>
    </body>
  </noframes>
</html>
EOF

