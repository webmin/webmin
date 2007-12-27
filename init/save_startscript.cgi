#!/usr/local/bin/perl
# save_startscript.cgi
# saves modifications to the StartupItems/script/script or
# the StartupItems/script/StartupItems.plist

# Even though it would be MUCH faster to pass the file to be edited
# in the form, forms are filled out by the browser, not the server.
#
# A malicious user could manipulate the form to write to
# any file they darned well please. While a user who has webmin access 
# to the bootup scripts could do a fair amount of damage anyway, I still
# would rather limit the possible files the cgi will write to to the
# actual bootup scripts.

# Written by Michael A. Peters <mpeters@mac.com> for
# webmin init module, based on save_local.cgi of same
# module. Written for Darwin/OS X.

require './init-lib.pl';
require './hostconfig-lib.pl';
use File::Basename;
$access{'bootup'} == 1 || &error("You are not allowed to edit the bootup script");
&ReadParse();

$action=$in{'action'};

if ( $in{'plist'} ne "" ) {
	$in{'plist'} =~ s/\r//g;
	$towrite = $in{'plist'};
	%temphash = &hostconfig_gather(startscript);
	$tempfile = $temphash{"$action"};
	$dir = dirname("$tempfile");
	$file = "$dir/$config{'plist'}";
	$redirect = "edit_hostconfig.cgi?0+$action";
	-e $file || &error("$file doesn't seem to exist");
	}
elsif ( $in{'startup'} ne "" ) {
	$in{'startup'} =~ s/\r//g;
	$towrite = $in{'startup'};
	%temphash = &hostconfig_gather(startscript);
	$file = $temphash{"$action"};
	$redirect = "edit_hostconfig.cgi?0+$action";
	-e $file || &error("$file doesn't seem to exist");
	}
elsif ( $in{'hostconfig'} ne "" ) {
	$in{'hostconfig'} =~ s/\r//g;
	$towrite = $in{'hostconfig'};
	$file = $config{'hostconfig'};
	$redirect = "edit_hostconfig.cgi?2";
	}
else {
	&error("I do not know what you want me to do");
	}

&lock_file($file);
&open_tempfile(LOCAL, "> $file");
&print_tempfile(LOCAL, $towrite);
&close_tempfile(LOCAL);
&unlock_file($file);
&webmin_log("startup", undef, undef, \%in);
&redirect("$redirect");
