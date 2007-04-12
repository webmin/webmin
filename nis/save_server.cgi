#!/usr/local/bin/perl
# save_server.cgi
# Save and apply NIS server options

require './nis-lib.pl';
&error_setup($text{'server_err'});
&ReadParse();
&parse_server_config();
&redirect("");

