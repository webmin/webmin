#!/usr/local/bin/perl
# restart_exporting.cgi
# Call unexportall and exportall to stop and re-start file exporting

require './hpuxexports-lib.pl';
$whatfailed = "Failed to apply changes";

$temp = &transname();
system("$config{unexport_all_command} >/dev/null 2>$temp");
$why = `/bin/cat $temp`;
unlink($temp);
#if ($why =~ /\S+/) {
#	&error("Unexport failed : </h2><pre>$why</pre>");
#	}
system("$config{export_all_command} >/dev/null 2>$temp");
$why = `/bin/cat $temp`;
unlink($temp);
if ($why =~ /\S+/) {
	&error("Export failed : </h2><pre>$why</pre>");
	}
unlink($temp);
&redirect("");

