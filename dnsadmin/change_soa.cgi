#!/usr/local/bin/perl
# change_soa.cgi
# Saves changes to the SOA record from edit_primary.cgi

require './dns-lib.pl';
$whatfailed = "Failed to save domain";
&ReadParse();
$d = $in{domain};

# Get the domain being edited
&get_primary($d);
for($i=0; $i<@name; $i++) {
	if ($type[$i] eq "SOA") { $soa = $i; last; }
	}

# Check user inputs
$in{serv} =~ /^[A-Za-z0-9\-\_\.]+$/ ||
	&error("$in{serv} is not a valid server hostname");
$in{serv} = &make_full($in{serv}, "$d.");
$in{mail} =~ /^[A-Za-z0-9\-\_\.]+\@[A-Za-z0-9\-\_\.]+$/ ||
	&error("$in{mail} doesn't look like a valid email address");
$in{mail} =~ s/\@/\./g; $in{mail} .= ".";
$in{refresh} =~ /^[0-9]+$/ ||
	&error("$in{refresh} is not a valid refresh period");
$in{retry} =~ /^[0-9]+$/ ||
	&error("$in{retry} is not a valid retry period");
$in{expire} =~ /^[0-9]+$/ ||
	&error("$in{expire} is not a valid expire time");
$in{min} =~ /^[0-9]+$/ ||
	&error("$in{min} is not a valid minimum TTL");

# Save and bounce back
$data[$soa] = "$in{serv} $in{mail} $in{serial} $in{refresh} $in{retry} $in{expire} $in{min}";
&save_primary($d);
&redirect("edit_primary.cgi?$d");

