#!/usr/local/bin/perl
# Output the XML settings file

BEGIN { push(@INC, ".."); };
use WebminCore;
$trust_unknown_referers = 1;
&init_config();
print "Content-type: text/plain\n\n";

# Work out host and port
$host = $ENV{'HTTP_HOST'};
$host =~ s/\:\d+$//;
$telnetport = $config{'telnetport'} || 23;

print <<EOF;
<connection 
	name="FlashTerm" 
	address="$host" 
	port="$telnetport" 
	socket_server_port="843" 
	info_graphic=""
	default_font=""
	columns="80"
	lines="25"
/>
EOF


