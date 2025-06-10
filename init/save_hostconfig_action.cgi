#!/usr/local/bin/perl
# save_hostconfig_action.cgi
#
# Creates a new StartupItems directory containing a script and
# plist, and adds the appropriate entry into the hostconfig file.
#
# Written by Michael A. Peters <mpeters@mac.com> for the webmin init 
# module for Darwin and OS X.

require './init-lib.pl';
$access{'bootup'} == 1 || &error("You are not allowed to edit the bootup script");
&ReadParse();

#make sure required fields have been filled out
if ( $in{'action_name'} eq "" ) {
	&error("The $text{'edit_hostconfig_actionname'} field may not be left blank");
	}
elsif ( $in{'script_name'} eq "" ) {
	&error("The $text{'edit_hostconfig_scriptname'} field may not be left blank");
	}
elsif ( $in{'execute'} eq "" ) {
	&error("The $text{'edit_start'} field may not be left blank");
	}
	
#check for legality of action name and script name
if (not $in{'action_name'}=~ /^[A-Z][A-Z0-9_]*$/ ) {
	&error("The $text{'edit_hostconfig_actionname'} should contain only upper case letters, numbers, and _ and should start with an upper case letter");
	}
else {
	#make sure action name is not in use
	open(LOCAL, "<$config{'hostconfig'}");
	@temp = <LOCAL>;
	close(LOCAL);
	foreach $element (@temp) {
		if ($element =~ /^$in{'action_name'}=(.*)$/ ) {
			&error("$in{'action_name'} is already in use. Please choose another value for $text{'edit_hostconfig_actionname'}");
			}
		}
	}
if (not $in{'script_name'}=~ /^[A-Za-z0-9_-]*$/ ) {
	&error("The $text{'edit_hostconfig_scriptname'} should contain only letters, numbers, _, and -");
	}
else {
	if ( -d "$config{'darwin_setup'}/$in{'script_name'}" ) {
	# Perl does know about hfs+ preservation but not sensitivity-
	# I checked :)
		&error("$in{'script_name'} is already in use for another action. Please choose another value for $text{'edit_hostconfig_scriptname'}");
		}
	}

#assign values	
$in{'execute'} =~ s/\r//g;
if ( $in{'start'} eq "" ) {
	$in{'start'} = "Starting $in{'script_name'}";
	}
if ( $in{'stop'} eq "" ) {
	$in{'stop'} = "Stopping $in{'script_name'}";
	}
if ( $in{'description'} eq "" ) {
	$in{'description'} = "No description available";
	}
	
#assign array values
if ( $in{'provides'} ne "" ) {
	@provides_array = split (/:/, $in{'provides'});
	$provides = "\"$provides_array[0]\"";
	if ( $provides_array[1] ne "" ) {
		shift @provides_array;
		foreach $element (@provides_array) {
			$provides = "$provides, \"$element\""
			}
		}
	}
if ( $in{'requires'} ne "" ) {
	@requires_array = split (/:/, $in{'requires'});
	$requires = "\"$requires_array[0]\"";
	if ( $requires_array[1] ne "" ) {
		shift @requires_array;
		foreach $element (@requires_array) {
			$requires = "$requires, \"$element\""
			}
		}
	}
if ( $in{'uses'} ne "" ) {
	@uses_array = split (/:/, $in{'uses'});
	$uses = "\"$uses_array[0]\"";
	if ( $uses_array[1] ne "" ) {
		shift @uses_array;
		foreach $element (@uses_array) {
			$uses = "$uses, \"$element\""
			}
		}
	}

# make array string
$array="";
if ( $provides ne "" ) {
	$array = "\tProvides\t= \($provides\);\n";
	}
if ( $requires ne "" ) {
	$array = "$array\tRequires\t= \($requires\);\n";
	}
if ( $uses ne "" ) {
	$array = "$array\tUses\t= \($uses\);\n";
	}
	
# make plist
$plist = "\{\n\tDescription\t= \"$in{'description'}\";\n$array\tOrderPreference\t= \"$in{'order'}\";\n\tMessages =\n\t\{\n\t\tstart\t= \"$in{'start'}\";\n\t\tstop\t=\"$in{'stop'}\";\n\t\};\n\}\n";

# make startscript
$startscript = "#!/bin/sh\n\n. /etc/rc.common\n\nif \[ \"\$\{$in{'action_name'}:=-NO-\}\" = \"-YES-\" \]; then\n\tConsoleMessage \"$in{'start'}\"\n$in{'execute'}\nfi\n";

# So write the files already!
if (not -d "$config{'darwin_setup'}") {
	mkdir ("$config{'darwin_setup'}", 0755);
	}
# startup dir for this action should not yet exist
mkdir ("$config{'darwin_setup'}/$in{'script_name'}", 0755) || &error("Could not create $config{'darwin_setup'}/$in{'script_name'}");

&open_tempfile(LOCAL, ">$config{'darwin_setup'}/$in{'script_name'}/$config{'plist'}");
&print_tempfile(LOCAL, $plist);
&close_tempfile(LOCAL);
chmod(0644, "$config{'darwin_setup'}/$in{'script_name'}/$config{'plist'}");

&open_tempfile(LOCAL, ">$config{'darwin_setup'}/$in{'script_name'}/$in{'script_name'}");
&print_tempfile(LOCAL, $startscript);
&close_tempfile(LOCAL);
chmod(0750, "$config{'darwin_setup'}/$in{'script_name'}/$in{'script_name'}");

&lock_file($config{'hostconfig'});
&open_tempfile(LOCAL, ">>$config{'hostconfig'}");
&print_tempfile(LOCAL, "$in{'action_name'}=$in{'boot'}\n");
&close_tempfile(LOCAL);
&unlock_file($config{'hostconfig'});
&webmin_log("new_action", undef, undef, \%in);
&redirect("edit_hostconfig.cgi?0+$in{'action_name'}");

#print "Content-type: text/plain", "\n\n";
#print "Debug\n\n";
#print "$plist";
#print "\n\n";
#print "$startscript";
#print "\n";
