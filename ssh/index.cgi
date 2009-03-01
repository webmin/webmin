#!/usr/local/bin/perl
# index.cgi
# Display the SSH applet

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
&ui_print_header(undef, "SSH Login", "", undef, 1, 1);

$addr = $config{'host'} ? $config{'host'}
			: &to_ipaddress(&get_system_hostname());
$config{'port'} = 22 if ($config{'port'} == 23);
print <<EOF;
<hr>
<center><applet archive=mindtermfull.jar code=com.mindbright.application.MindTerm.class width=600 height=420>
<param name=te value="xterm-color">
<param name=gm value="80x24">
<param name=server value="$addr">
<param name=port value="$config{'port'}">
<param name=cipher value="3des">
<param name=sepframe value="false">
<param name=quiet value="false">
<param name=cmdsh value="true">
<param name=verbose value="true">
<param name=autoprops value="none">
<param name=idhost value="false">
<param name=quiet value="true">
<param name=alive value="10">

Your browser does not appear to support java, which this module
requires to function. <p>
</applet><br>
Applet developed under GPL by <a href=http://www.mindbright.se/mindterm/>Mindbright</a>.
</center>
<hr>
EOF
&ui_print_footer("/", "index");

