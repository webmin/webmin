#!/usr/local/bin/perl
# modifyhostconfig.cgi
# Rewrites the hostconfig file

# Written by Michael A. Peters <mpeters@mac.com>
# for OSX/Darwin

require './init-lib.pl';
$access{'bootup'} == 1 || &error("You are not allowed to edit the bootup script");
&ReadParse();

if ( $in{'choice'} eq "custom" ) {
	$setting = $in{'custom'};
	}
else {
	$setting = $in{'choice'};
	}
	
if ( $setting =~ /^\%22(.*)\%22$/ ) {
	$setting = $1;
	}
	
$setting =~ s/\+/ /g;
if ( $setting =~ /[ ]/ ) {
	$setting = "\"$setting\"";
	}

# not all possible blunders are fixed, but at least intelligently
# made ones...

$setting = "$in{'action'}=$setting";

$hostc = $config{'hostconfig'};
# modify and write the hostconfig file
@new = ();
&lock_file($config{'hostconfig'});
open(LOCAL, "$hostc");
@old = <LOCAL>;
close(LOCAL);
foreach $line (@old) {
	$line =~ s/^$in{'action'}=(.*)$/$setting/;
	push @new, $line;
	}

&open_tempfile(LOCAL, "> $config{'hostconfig'}");
&print_tempfile(LOCAL, @new);
&close_tempfile(LOCAL);
&unlock_file($config{'hostconfig'});
&webmin_log("hostconfig", undef, undef, "\%in");
&redirect("");
