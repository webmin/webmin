#!/usr/local/bin/perl
# hostconfig-lib.pl

# These are functions specific to the hostconfig file
# used by darwin

# written by Michael A. Peters <mpeters@mac.com>

sub hostconfig_settings
{
####
#
# This subroutine reads the hostconfig file into an array
# and outputs a second array containing matched pairs of
# the startup action and what the startup action is set to
#
####
local($conffile, @hconf);
$conffile = "$config{'hostconfig'}";
open(LOCAL, $conffile);
@conf = <LOCAL>;
close(LOCAL);
@conf = grep /^\w/, @conf;
while (<@conf>) {
	push @hconf, [ split /=/ ];
	}
return @hconf;
}

sub hostconfig_gather
{
####
#
# Gathers information about an action item that is set in the hostconfig
# file.
#
# It takes one arguement- the type of info wanted (description or 
# scriptname)
#
# It outputs a hash where the action item is the key, and what was 
# requested is the value.
#
# Thus, we can use the hash to find out what startup script is 
# associated with the MAILSERVER action or what description goes with 
# that action.
#
# Originally I wanted to output an array with two elements where the 
# first was one type of hash, and the second element was the second type # of hash, but I couldn't get that to work (array of hashes)
#
####
local ($hash_type, @startupdir, $plist, @action_to_description, @action_to_script, @sec_action_to_description, @sec_action_to_script, $element, @ls, @script, $a, $action_name, @param, $description);

my($hash_type) = @_;
@startupdir = ();
@startupdir = split (/:/, $config{'startup_dirs'});
$plist = $config{'plist'};
@action_to_description = ();
@action_to_script = ();
@sec_action_to_description = ();
@sec_action_to_script = ();

foreach $element (@startupdir) {
	if ( -d "$element" ) {
		opendir (LOCAL, $element);
		@ls = readdir LOCAL;
		closedir LOCAL;
		shift @ls; shift @ls;
		foreach $a (@ls) {
			#we need BOTH an executable and a plist- or its useless.
			#executable script has to be in a directory of the same
			#name for some reason
			if (( -x "$element/$a/$a") && ( -e "$element/$a/$plist")) {
				#Get the startup action associated with script
				open (SCRIPT, "$element/$a/$a");
				@script = <SCRIPT>;
				close SCRIPT;
				@script = grep /:=/, @script;
				#  we are looking at a line in the script that looks like:
				#if [ "${WEBMIN:=-NO-}" = "-YES-" ]; then
				#  and we want to extract the WEBMIN part as the action_name
				if ( $script[0] =~ /\$\{(.*):/ ) {
					$action_name = $1;
					}
				else {
					#shouldn't happen
					$action_name = "";
					}
				open (PLIST, "$element/$a/$plist");
				@param = <PLIST>;
				close PLIST;
				@param = grep /Description[ \t]*=/, @param;
				#  we are looking at a line in the plist that looks like:
				#\t\tDescription\t\t= "Webmin System Administration Daemon";
				#  and we want to extract the contents of the quotes
				if ( $param[0] =~ /\"(.*)\"/ ) {
					$description = $1;
					}
				else {
					$description = "";
					}
				# make the primary hash
				if ( $action_name ne "" ) {
					$action_to_description{$action_name} = "$description";
					$action_to_script{$action_name} = "$element/$a/$a";
					}
				# make the secondary hash
				shift @script;
				if ( $script[0] ne "" ) {
					foreach $secondary (@script) {
						if ( $secondary =~ /\$\{(.*):/ ) {
							$action_name = $1;
							$sec_action_to_description{$action_name} = "$description";
							$sec_action_to_script{$action_name} = "$element/$a/$a";
							}
						}
					}
				} #ends the: if (( -x "$element/$a/$a") && ( -e "$element/$a/$plist")
			} #ends the: foreach $a (@ls)
		} #ends the: if ( -d "$element" )
	} #ends the: foreach $element (@startupdir)
	
# now we have two sets of each hash
# elements in sec_blah that are not already in blah
# need to be integrated into blah
#
# We have to do this because some scripts use several action_name just 
# for that particular script, and sometimes what one action is set to is 
# used in how another script acts even though that is not the action for # that script.
#
# Thus, if a action_item is in the secondary array and is not in the
# primary, we know that it is a case where more than one action belongs
# to a script- but if its in both, the action probably belongs to the
# script in the primary.

while (($key,$value) = each %action_to_description) {
	$sec_action_to_description{$key} = "$value";
	}
while (($key,$value) = each %action_to_script) {
	$sec_action_to_script{$key} = "$value";
	}
	
if ( $hash_type eq "description" ) {
	return %sec_action_to_description;
	}
elsif ( $hash_type eq "startscript" ) {
	return %sec_action_to_script;
	}

}

sub hostconfig_table
{
####
#
# This sub writes a table row in html for index.cgi.
# It takes the startup action, setting, and provides
# as its arguements- and outputs a string.
#
####
local($ahref, $setting, $link, $description);
my($ahref, $setting, $description) = @_;
local @cols;
if ($access{'bootup'} == 1) {
	push(@cols, &ui_link("edit_hostconfig.cgi?0+$ahref", $ahref) );
	}
else {
	push(@cols, $ahref);
	}
if ( $setting eq "-NO-" ) {
	push(@cols, "<font color=#ff0000>$setting</font>");
	}
elsif ( $setting ne "" ) {
	push(@cols, $setting);
	}
else {
	push(@cols, "");
	}
push(@cols, $description);
if ( $ahref ne "" ) {
	return &ui_columns_row(\@cols);
	}
else {
	return "<!-- this is annoying- I'll have to track it down.. -->";
	}
}

sub hostconfig_editaction
{
####
#
# This sub takes either one or two arguements- the first (action name)
# is required, the second is the StartupItems script affected by
# the setting of the action. 
#
# If there is no script, the current setting is used as the default in
# a text field for editing.
#
# If there is a script, but the setting is something like automatic in 
# the Network script where there isn't an alternative, then radio button # choice between the defined setting and a custom one is offered.
#
# If, as is the case with most scripts, there is a -NO- and -YES- 
# option, then those two choices are offered as a radio button option 
# and a text box option just in case a custom answer is needed.
#
# Returns a string
#
####
local(@sconf, @sfile, @possible_settings, $current, $setting, $line, $option_selected, $buttons, $pre);
my($action_item, $startupfile) = @_;

# get current setting
$line = "$config{'hostconfig'}";
open(HCONF, $line);
@sconf = <HCONF>;
close(HCONF);
@sconf = grep /^$action_item=/, @sconf;
($dontcare, $current) = split(/=/, $sconf[0]);
if ( $current eq "" ) {
	$current = "udefined";
	}
#get rid of quotes
$current =~ s/\"//g;
$current =~ s/\n//;

@possible_settings = ();
$option_selected = "";
$buttons = "";
$option_selected = "";

# get possible settings
if ( $startupfile ne "" ) {
	open(LOCAL, $startupfile);
	@sfile = <LOCAL>;
	close(LOCAL);
	#
	# I really need to write a parser to get
	# this done- so that I can deal with
	# case options.
	#
	# But this is better than nothing...
	#
	@sfile = grep /\{$action_item:=/, @sfile;
	for $element (@sfile) {
		# We are looking at a line that looks like
		#if [ "${WEBMIN:=-NO-}" = "-YES-" ]; then
		# We want the -NO- and -YES-
		if ( $element =~ /\"\$\{$action_item:=(.*)\}\"[ \t]*=[ \t]*\"(.*)\"/ ) {
			push @possible_settings, ($1, $2);
			}
		}
	# get rid of duplicate entries
	%unique = map { $_ => 1 } @possible_settings;
	@possible_settings = keys %unique;
	} # end of :if ( $startupfile ne "" )
	
if ( $possible_settings[0] eq "" ) {
	$buttons = "<input type=text name=choice value=\"$current\">";
	}
else {
	foreach $setting (@possible_settings) {
		if ( $setting ne $current ) {
			if ( $buttons eq "" ) {
				$pre = "";
				}
			else {
				$pre = "$buttons<br>\n";
				}
			$buttons = "$pre<input type=radio name=choice value=\"$setting\">$setting";
			}
		else {
			$option_selected = "yes";
			if ( $buttons eq "" ) {
				$pre = "";
				}
			else {
				$pre = "$buttons<br>\n";
				}
			$buttons = "$pre<input type=radio name=choice value=\"$setting\" checked>$setting";
			}
		} #end foreach
	# add custom text option
	if ( $option_selected eq "yes" ) {
		$buttons = "$buttons<br>\n<input type=radio name=choice value=custom> <input type=text name=custom size=60 value=\"\">";
		}
	else {
		$buttons = "$buttons<br>\n<input type=radio name=choice value=custom checked> <input type=text name=custom size=60 value=\"$current\">";
		}
	}
# add hidden value
$buttons = "$buttons\n<input type=hidden name=action value=$action_item>\n";
	
return $buttons;

}

sub hostconfig_createtext
{
# simply outputs the text in the create new action table
my($text_line,$required_field) = @_;
if ( $required_field ne "" ) {
	$output="<td><font size=-1 color=#ff0000>*</font><b>$text_line</b></td>\n";
	}
else {
	$output="<td><b>$text_line</b></td>\n";
	}
return $output;
}
1;
