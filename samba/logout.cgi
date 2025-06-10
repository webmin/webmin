#!/usr/local/bin/perl
# logout.cgi
# Forget the current SWAT login and password

require './samba-lib.pl';

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pcswat'}") unless $access{'swat'};
 
unlink("$module_config_directory/swat");
&redirect("swat.cgi");

