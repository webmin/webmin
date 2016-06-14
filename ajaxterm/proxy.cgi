#!/usr/local/bin/perl
# Proxy an Ajaxterm request to the real port
use strict;
use warnings;

BEGIN { push(@INC, ".."); };
use WebminCore;

# Since this script is run on every keypress, init_config is intentionally
# not called to reduce startup time.
#&init_config();

# Parse out port
$ENV{'PATH_INFO'} =~ /^\/(\d+)(.*)$/ ||
	&error("Missing or invalid PATH_INFO");
my $port = $1;
my $path = $2;
$| = 1;
my $meth = $ENV{'REQUEST_METHOD'};

# Connect to the Ajaxterm server, send HTTP request
my $con = &make_http_connection("localhost", $port, 0, $meth, $path);
&error($con) if (!ref($con));
&write_http_connection($con, "Host: localhost\r\n");
&write_http_connection($con, "User-agent: Webmin\r\n");
my $cl = $ENV{'CONTENT_LENGTH'};
&write_http_connection($con, "Content-length: $cl\r\n") if ($cl);
&write_http_connection($con, "Content-type: $ENV{'CONTENT_TYPE'}\r\n")
        if ($ENV{'CONTENT_TYPE'});
&write_http_connection($con, "\r\n");
my $post;
if ($cl) {
        &read_fully(\*STDIN, \$post, $cl);
        &write_http_connection($con, $post);
        }

# read back the headers
my $dummy = &read_http_connection($con);
my %header;
my $headers;
while(1) {
        my $headline;
        ($headline = &read_http_connection($con)) =~ s/\r|\n//g;
        last if (!$headline);
        $headline =~ /^(\S+):\s+(.*)$/ || &error("Bad header");
        $header{lc($1)} = $2;
        $headers .= $headline."\n";
        }
print $headers,"\n";

# read back contents
while(my $buf = &read_http_connection($con, 1024)) {
	print $buf;
        }
&close_http_connection($con);

# Touch status file to indicate it is still running
my $statusdir = $ENV{'WEBMIN_VAR'}."/ajaxterm";
if (!-d $statusdir) {
	&make_dir($statusdir, 0700);
	}
my $TOUCH;
&open_tempfile($TOUCH, ">$statusdir/$port", 0, 1);
&close_tempfile($TOUCH);

