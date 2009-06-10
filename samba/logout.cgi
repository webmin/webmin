#!/usr/local/bin/perl
# logout.cgi
# Forget the current SWAT login and password

require './samba-lib.pl';

# check acls

&error_setup("<blink><font color=red>$text{'eacl_aviol'}</font></blink>");
&error("$text{'eacl_np'} $text{'eacl_pcswat'}") unless $access{'swat'};
 
unlink("$module_config_directory/swat");
&redirect("swat.cgi");

