#!/usr/bin/perl -U

@uinfo = getpwnam("nobody");
($(, $)) = ( $uinfo[3], "$uinfo[3] $uinfo[3]" );
($<, $>) = ( $uinfo[2], $uinfo[2] );
$ENV{'USER'} = "nobody";
#exec("strace -f cgi-bin/shellinabox.cgi 2>/tmp/trace.out");
exec("cgi-bin/shellinabox.cgi");
print "Content-type: text/plain\n\n";
print "exec failed : $!\n";

