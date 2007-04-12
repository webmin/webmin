#!/usr/local/bin/perl

require './proc-lib.pl';
&ReadParse();
$idfile = "$module_config_directory/$in{'id'}.tail";
open(IDFILE, $idfile) || exit;
chop($pid = <IDFILE>);
close(IDFILE);
$pid || exit;
kill('HUP', $pid);
sleep(2);
kill('KILL', $pid);
unlink($idfile);
print "Content-type: text/plain\n\n";
print "$pid\n";

