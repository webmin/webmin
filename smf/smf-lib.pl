#!/usr/local/bin/perl
# Common functions for managing smf services

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
require '../javascript-lib.pl';

do 'wizard.pl';

$lib = get_mod_lib();
if ($lib) {
	do "$lib";
	}

# Hash matching svc type to prefix
%svc_types = ("Network", "svc:/network/",
	"System", "svc:/system/",
	"Legacy", "lrc:/",
	"Milestone", "svc:/milestone/",
	"Platform-specific", "svc:/platform/",
	"Application", "svc:/application/",
	"Device-specific", "svc:/device/",
	"Site-specific", "svc:/site/",
	"All", "svc:/");

# Hash matching svc option to description
%svc_options = ("FMRI", "FMRI",
	"STATE", "State",
	"DESC", "Description",
	"STIME", "StartTime",
	"NSTATE", "NextState");

# defaults for main svc page
$default_svc_options = "FMRI,STATE,DESC";
$default_sortopt = "-SSTATE";
$default_include_disabled = 0;

# this hash associates smf states with colors
%state_colors = ("online", "green",
	"offline", "yellow",
	"maintenance", "red",
	"legacy_run", "gray",
	"disabled", "gray");

# this variable is used to record commands run. these are then
# displayed at bottom of page, in msg "this page was generated using
# commands $cmds_run".

$cmds_run = "";

$maxint = 65535;

# this array constitutes the specification of the smf service
# creation wizard
$wizard = "page=smfwizard_service.cgi,min=1,max=1; \
	page=smfwizard_instance.cgi,min=1,max=$maxint; \
	page=smfwizard_restarter.cgi,min=0,max=1; \
	page=smfwizard_dependency.cgi,min=0,max=$maxint; \
	page=smfwizard_dependent.cgi,min=0,max=$maxint; \
	page=smfwizard_exec.cgi,min=0,max=$maxint; \
	page=smfwizard_property_group.cgi,min=0,max=$maxint; \
	page=smfwizard_property.cgi,min=0,max=$maxint; \
	page=smfwizard_template.cgi,min=0,max=1; \
	page=smfwizard_manpage.cgi,min=0,max=$maxint; \
	submit=smfwizard_process_submit.cgi";

# Array of boolean values
@boolean_values = ("true", "false");

# Array of dependency/dependent types
@dep_types = ("service", "path");
# Array of restart_on values
@restart_on_values = ("none", "fault", "restart", "refresh", "error");
# Array of grouping values
@grouping_values = ("require_all", "require_any", "optional_all",
        "exclude_all");
# Array of property value types
@propval_type_values = ("count", "integer", "opaque", "host", "hostname",
"net_address_v4", "net_address_v6", "time", "astring", "ustring", "boolean",
"fmri", "uri");

# Array of stability values
@stability_values = ("Evolving", "Unstable", "External", "-");

# Array of number of lines choices for logfile viewer
@logfile_numlines_values = ("20", "40", "80", "160", "all");

# subroutines used to run/check/log smf commands.

# Run all smf commands (separated by ";", check if expected retvals match
# (if needed) and return response(s)
#
# Parameters: cmdlist, [expected_retval]
#
sub run_smf_cmds()
{
local ($cmdlist, $expected_retval, @cmds, $errmsg, $response, $cmd,
	$newresponse, $retval);
($cmdlist, $expected_retval) = @_;
@cmds = split(/;/, "$cmdlist");
$errmsg = "";
$response = "";
foreach $cmd (@cmds) {
	$newresponse = &backquote_logged("$cmd");
	$retval = $?;
	if ($response =~ /.+/) {
		# append to responses so far...
		$response = "$response ; $newresponse";
	} else {
		$response = "$newresponse";
		}
	# check retval
	if (($expected_retval =~ /.+/) &&
	    ($expected_retval != $retval)) {
		$errmsg =
"${errmsg}Unexpected return value $retval from $cmd: $newresponse .";
		}
	if ($cmds_run =~ /.+/) {
		$cmds_run = "$cmds_run ; $cmd";
	} else {
		$cmds_run = "$cmd";
		}
	}
if ($errmsg =~ /.+/) {
	&error("$errmsg");
	}
return $response;
}

# Import supplied manifest into repository, expect success
#
# Parameters: manifest
#
sub svc_import()
{
$manifest = $_[0];
&run_smf_cmds("/usr/sbin/svccfg import $manifest", 0);
}

# get dependencies/dependent listing for fmri
#
# Parameters: dependency_or_dependent, fmri
#
sub svc_dep_cmd()
{
local ($dependency_or_dependent, $fmri, $cmd);
($dependency_or_dependent, $fmri) = @_;

if ($dependency_or_dependent eq "dependent") {
	$cmd = "/usr/bin/svcs -H -oFMRI,STATE -D $fmri";
} else {
	$cmd = "/usr/bin/svcs -H -oFMRI,STATE -d $fmri";
	}
return (&run_smf_cmds("$cmd"));
}

# get grouping for child dependency on parent fmri using svcs -l
#
# Parameters: parent_fmri child_fmri
#
sub svc_grouping_cmd()
{
local ($parent_fmri, $child_fmri, $output, @output_lines, $line, $grouping);
($parent_fmri, $child_fmri) = @_;
$output = &run_smf_cmds("/usr/bin/svcs -l $parent_fmri");
@output_lines = split(/\n/, $output);
foreach $line (@output_lines) {
	chomp($line);
	if ($line =~ /dependency\s+([^\/]+)\/\S+\s+$child_fmri/) {
		# found dependency at instance level
		$grouping = $1;
		return $grouping;
		}
	}
# if no match at instance level, we try service level...
if ($child_fmri =~ /(svc:\/[^:]*):.*/) {
	$child_fmri_svc = $1;
	return (&svc_grouping_cmd($parent_fmri, $child_fmri_svc));
} else {	
	return "";
	}
}

# apply svc command to elts in fmri list
#
# Parameters: cmd, fmri
sub svc_state_cmd()
{
local ($cmd_name, $fmrilist_ref, $cmd, $cmdlist, $fmri);
($cmd_name, $fmrilist_ref) = @_;
if ($cmd_name eq "$text{'state_enable'}") {
	$cmd = "/usr/sbin/svcadm enable";
} elsif ($cmd_name eq "$text{'state_disable'}") {
	$cmd = "/usr/sbin/svcadm disable";
} elsif ($cmd_name eq "$text{'state_refresh'}") {
	$cmd = "/usr/sbin/svcadm refresh";
} elsif ($cmd_name eq "$text{'state_restart'}") {
	$cmd = "/usr/sbin/svcadm restart";
} elsif ($cmd_name eq "$text{'state_maintenance'}") {
	$cmd = "/usr/sbin/svcadm mark maintenance";
} elsif ($cmd_name eq "$text{'state_degraded'}") {
	$cmd = "/usr/sbin/svcadm mark degraded";
} elsif ($cmd_name eq "$text{'state_clear'}") {
	$cmd = "/usr/sbin/svcadm clear";
} elsif ($cmd_name eq "$text{'index_delete'}") {
	$cmd = "/usr/sbin/svccfg delete -f";
} else {
	&error("Unknown command $cmd_name!");
	}
$cmdlist = "";
foreach $fmri (@$fmrilist_ref) {
	$cmdlist = "${cmdlist}$cmd $fmri;";
	}
return (&run_smf_cmds("$cmdlist", 0));
}

# get state for instance
#
# Parameters: fmri
#
sub svc_get_state_cmd()
{
local ($fmri, $state);
$fmri = $_[0];
$state = &run_smf_cmds("/usr/bin/svcs -H -oSTATE $fmri");
chomp($state);
return $state;
}

# add/delete/list propgroup/prop commands
#
# 

# Add property group
#
# Parameters: fmri, service_or_instance, name, type
#
sub svc_addpg()
{
local($fmri, $sinst, $name, $type, $entity);
($fmri, $sinst, $name, $type) = @_;
$entity = ($sinst eq "service") ? "$fmri" : "$fmri:$sinst";
&run_smf_cmds
("/usr/bin/echo \"select $entity\naddpg $name $type\nquit\n\"  | /usr/sbin/svccfg", 0);
}

# Delete property group
#
# Parameters: fmri, service_or_instance, name
#
sub svc_delpg()
{
local($fmri, $sinst, $name, $entity);
($fmri, $sinst, $name) = @_;
$entity = ($sinst eq "service") ? "$fmri" : "$fmri:$sinst";
&run_smf_cmds
("/usr/bin/echo \"select $entity\ndelpg $name\nquit\n\"  | /usr/sbin/svccfg",
	0);
}

# list property groups. we also determine if property group is at service
# or instance level and include this in listing.
#
# Parameters: fmri, service_or_instance
#
sub svc_listpg()
{
local ($fmri, $sinst, $entity, $pgroups, @pgroup_list, $i, $pgroup_info,
	$name, $type, @listing);
($fmri, $sinst) = @_;
$entity = ($sinst eq "service") ? "$fmri" : "$fmri:$sinst";
$pgroups = &run_smf_cmds
    ("/usr/bin/echo \"select $entity\nlistpg\nquit\n\"  | /usr/sbin/svccfg", 0);
@pgroup_list = split(/\n/, $pgroups);
$i = 0;
foreach $pgroup_info (@pgroup_list) {
	$pgroup_info =~ /([^\s]*)\s+(.*)/;
	$name = $1;
	$type = $2;
	$listing[$i]{'pgroup_name'} = $1;
	$listing[$i]{'pgroup_type'} = $2;
	$listing[$i]{'sinst'} = $sinst;
	$i = $i + 1;
	}
return @listing;
}

# Set property (creates if doesn't yet exist)
#
# Parameters: fmri, service_or_instance, pgname, name, type, value
#
sub svc_setprop()
{
local($fmri, $sinst, $pgname, $pname, $type, $value, $entity);
($fmri, $sinst, $pgname, $pname, $type, $value) = @_;
$entity = ($sinst eq "service") ? "$fmri" : "$fmri:$sinst";
&run_smf_cmds
("/usr/bin/echo \"select $entity\nsetprop $pgname/$pname=$type:\\\"$value\\\"\nquit\n\" | /usr/sbin/svccfg", 0);
}

# Delete property 
#
# Parameters: fmri, service_or_instance, pgroup_name, name
#
sub svc_delprop()
{
local($fmri, $sinst, $pgname, $name, $entity);
($fmri, $sinst, $pgname, $name) = @_;
$entity = ($sinst eq "service") ? "$fmri" : "$fmri:$sinst";
&run_smf_cmds
("/usr/bin/echo \"select $entity\ndelprop $pgname/$name\nquit\n\" | /usr/sbin/svccfg", 0);
}

# list properties
#
# Parameters: fmri, service_or_instance, pgroup_name
#
sub svc_listprop()
{
local ($fmri, $sinst, $entity, $pgroup_name, $props, @prop_list, $i,
	$prop_info, $name, $type, $value, @listing);
($fmri, $sinst, $pgroup_name) = @_;
$entity = ($sinst eq "service") ? "$fmri" : "$fmri:$sinst";
$props = &run_smf_cmds
    ("/usr/bin/echo \"select $entity\nlistprop $pgroup_name/\*\nquit\n\"  | /usr/sbin/svccfg", 0);
@prop_list = split(/\n/, $props);
$i = 0;
foreach $prop_info (@prop_list) {
	$prop_info =~ /[^\/]*\/([^\s]+)\s+([^\s]*)\s+(.*)/;
	$listing[$i]{'prop_name'} = $1;
	$listing[$i]{'prop_type'} = $2;
	$listing[$i]{'prop_value'} = $3;
	$i = $i + 1;
	}
return @listing;
}

# general subroutines: whats this links, converting links in text etc.
#

# wrapper for printing text and associated whats this link if required
#
# Parameters: text
#
sub text_and_whats_this()
{
local ($textname);
$textname = $_[0];
if ($config{'enable_whats_this'} == 1) {
	print "$text{$textname}&nbsp;", &hlink($text{'whats_this'}, $textname);
	}
else {
	print "$text{$textname}";
	}
}

# Show what`s this? link, which opens new page with tip info. We pass in
# pagename and tipname, and the appropriate localized string, representing
# a concatenation of the two, is displayed.
#
# Parameters: tiparea, tipname
#
sub print_whats_this_link()
{
local($tipname);
$tipname = $_[0];
if ($config{'enable_whats_this'} == 1) {
	print "<a href=\"whats_this.cgi?tipname=$tipname\" target=\"new\">$text{'whats_this'}</a>";
	}
}

# convert manpage references to links, and http references to actual links
#
# Parameters: text
#
sub convert_links_in_text()
{
local($text);
$text = $_[0];
# convert http links,fmris,manpages and logfiles to links...
$text =~ s/See:\s+([^\(]*)\(([^\)]*)\)/See: <a href=\"\/man\/view_man.cgi?page=$1&sec=$2\">$1\($2\)<\/a>/g;
$text =~ s/http:\/\/(\S+)/<a href=\"http:\/\/$1\">http:\/\/$1<\/a>/g;
$text =~ s/(svc:\/\S+)/<a href=\"instance_viewer.cgi?fmri='$1'\">$1<\/a>/g;
$text =~
  s/(\/var\/svc\/log\/\S+)/<a href=\"log_viewer.cgi?logfile='$1'\">$1<\/a>/g;
$text =~
s/(\/etc\/svc\/volatile\/\S+)/<a href=\"log_viewer.cgi?logfile='$1'\">$1<\/a>/g;
return $text;
}

# show selection
#
# Parameters: name, selected, selection_arrayref
#
sub print_selection()
{
local($name, $selected, $selection_arrayref, @array, $elt, $select);
($name, $selected, $selection_arrayref) = @_;
print "<select name=\"$name\" size=1>\n";
@array = @$selection_arrayref;
foreach $elt (@array) {
        $select = "";
        if ($elt eq $selected) {
                $select = "selected";
                }
        print "<option $select>$elt</option>\n";
        }
print "</select>\n";
}

# shows commands run in generating page...
#
# Parameters:
#
sub print_cmds_run()
{
local ($cmds_run_clipped);
$cmds_run_clipped = substr($cmds_run, 0, 240);
print "<hr>\n";
print "<p>$text{'cmds_run'}:<\p>\n";
print "<p>${cmds_run_clipped}...</p>\n";
}

# show buttons to enable/disable etc
#
# Parameters:
#
sub print_state_buttons()
{
print "<input type=submit name=\"change_state\" value=\"$text{'state_enable'}\">&nbsp;\n";
print "<input type=submit name=\"change_state\" value=\"$text{'state_disable'}\">&nbsp;\n";
print "<input type=submit name=\"change_state\" value=\"$text{'state_refresh'}\">&nbsp;\n";
print "<input type=submit name=\"change_state\" value=\"$text{'state_restart'}\">&nbsp;\n";
print "<input type=submit name=\"change_state\" value=\"$text{'state_maintenance'}\">&nbsp;\n";
print "<input type=submit name=\"change_state\" value=\"$text{'state_degraded'}\">&nbsp;\n";
print "<input type=submit name=\"change_state\" value=\"$text{'state_clear'}\">&nbsp;\n";
}

# show svc chooser button
#
# Parameters: prop_name, form_index, button_value, type, add
#
sub print_svc_chooser()
{
($prop_name, $form_index, $button_value, $type, $add) = @_;
print "<input type=button onClick='ifield = document.forms[$form_index].$prop_name; chooser= window.open(\"svc_chooser.cgi?type=$type&add=$add\", \"chooser\", \"toolbar=no,menubar=no,scrollbar=no,width=500,height=400\"); chooser.ifield = ifield; window.ifield = ifield' value=\"$button_value\">\n";
}

# show path chooser button
#
# Parameters: prop_name, form_index, button_value, add
#
sub print_path_chooser()
{
($prop_name, $form_index, $button_value, $add) = @_;
print "<input type=button onClick='ifield = document.forms[$form_index].$prop_name; chooser= window.open(\"path_chooser.cgi?add=$add\", \"chooser\", \"toolbar=no,menubar=no,scrollbar=no,width=500,height=400\"); chooser.ifield = ifield; window.ifield = ifield' value=\"$button_value\">\n";
}

# subroutines used by index page

# gather required information from svcs, storing as
# array of hashes indexed by property...
# 
# Parameters: filter, comma_separated_optlist
#
sub svcs_listing()
{
local ($filter, $opts, $opt, @optlist, @sinfo, $sinf, @sinf_array, $i);
($filter, $sortopt) = @_;
$filter = "$filter\*";
$allopts = "FMRI,STATE,NSTATE,STIME,DESC";
$sinfo = &run_smf_cmds("/usr/bin/svcs -H -o $allopts $sortopt $filter");
@sinfo_list = split(/\n/, $sinfo);
foreach $sinf (@sinfo_list) {
	chomp($sinf);
	if ($sinf =~ /(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.*)/) {
		$listing[$i]{'FMRI'} = $1;
		$listing[$i]{'STATE'} = $2;
		$listing[$i]{'NSTATE'} = $3;
		$listing[$i]{'STIME'} = $4;
		$listing[$i]{'DESC'} = $5;
		$i = $i + 1;
		}
	}
return @listing;
}

# subroutines used in wizard-based service creation

# subfunction to create smf manifest from wizard datafiles.
#
# Parameters:

sub create_smf_manifest()
{
local (%service_info, $manifest, @find_replace_array, @datafiles, $i);
$manifest = $_[0];
unlink($manifest);
# add service information to manifest
%service_info = &wizard_get_data("smfwizard_service.cgi", "0");
@find_replace_array = ("SERVICE_NAME/$service_info{'service_name'}",
	"SERVICE_VERSION/$service_info{'service_version'}");
&fill_manifest_template("service_template.xml", $manifest,
	\@find_replace_array);
# restarter
%service_info = &wizard_get_data("smfwizard_restarter.cgi", "0");
if ($service_info{'restarter_fmri'} =~ /.+/) {
	@find_replace_array =
  ("RESTARTER_FMRI/<service_fmri value=\'$service_info{'restarter_fmri'}\' />");
	&fill_manifest_template("restarter_template.xml", $manifest,
		\@find_replace_array);
	}
&add_service_or_instance_info($manifest, "service");
@datafiles = &list_wizard_datafiles("smfwizard_instance.cgi");
for ($i = 0; $i < @datafiles; $i++) {
	%service_info = &wizard_get_data("smfwizard_instance.cgi", $i);
	@find_replace_array = ("INSTANCE_NAME/$service_info{'instance_name'}",
		"INSTANCE_ENABLED/$service_info{'instance_enabled'}");
	&fill_manifest_template("instance_template.xml", $manifest,
		\@find_replace_array);
	&add_service_or_instance_info($manifest,
		"$service_info{'instance_name'}");
	@find_replace_array = ();
	&fill_manifest_template("instance_template_end.xml", $manifest,
		\@find_replace_array);
	}
# template info
%service_info = &wizard_get_data("smfwizard_template.cgi", "0");
@find_replace_array =
	("TEMPLATE_COMMON_NAME/$service_info{'template_common_name'}",
	"TEMPLATE_DESCRIPTION/$service_info{'template_description'}");
if (($service_info{'template_common_name'} =~ /.+/) &&
    ($service_info{'template_description'} =~ /.+/)) {
	&fill_manifest_template("template_template.xml", $manifest,
		\@find_replace_array);
	@datafiles = &list_wizard_datafiles("smfwizard_manpage.cgi");
	for ($i = 0; $i < @datafiles; $i++) {
		%service_info = &wizard_get_data("smfwizard_manpage.cgi", $i);
		@find_replace_array =
		("MANPAGE_TITLE/$service_info{'manpage_title'}",
		"MANPAGE_SECTION/$service_info{'manpage_section'}",
		"MANPAGE_MANPATH/$service_info{'manpage_manpath'}");
		&fill_manifest_template("manpage_template.xml", $manifest,
			\@find_replace_array);
		}
	@find_replace_array = ();
	&fill_manifest_template("template_template_end.xml", $manifest,
		\@find_replace_array);
	}
@find_replace_array = ();
&fill_manifest_template("service_template_end.xml", $manifest,
	\@find_replace_array);
}

# subfunction to add dependecy/dependent/exec method/propgroup/prop
# information to manifest. if at service level, we look for sinst=service,
# otherwise, look for matches to instance name
#
sub add_service_or_instance_info()
{
local ($manifest, $sinst, @datafiles, $i, %service_info, $stability,
	@find_replace_array, $stability, $cred, $pgroup_name, $pgroup_type,
	$j, @propfiles, %prop_info);
($manifest, $sinst) = @_;
@datafiles = &list_wizard_datafiles("smfwizard_dependency.cgi");
for ($i = 0; $i < @datafiles; $i++) {
	%service_info = &wizard_get_data("smfwizard_dependency.cgi", $i);
	# does sinst match?
	if ("$service_info{'sinst'}" eq "$sinst") {
		# add dep'y
		if ($service_info{'dependency_stability'} eq "-") {
			$stability = "";
		} else {
			$stability =
		"<stability value='$service_info{'dependency_stability'}'/>";
			}
		@find_replace_array =
		    ("DEP_NAME/$service_info{'dependency_name'}",
		     "DEP_TYPE/$service_info{'dependency_type'}",
		     "DEP_GROUPING/$service_info{'dependency_grouping'}",
		     "DEP_RESTART_ON/$service_info{'dependency_restart_on'}",
	"DEP_FMRI/<service_fmri value=\'$service_info{'dependency_fmri'}\' />",
		     "DEP_STABILITY/$stability");
		&fill_manifest_template("dependency_template.xml", $manifest,
			\@find_replace_array);
		}
	}
@datafiles = &list_wizard_datafiles("smfwizard_dependent.cgi");
for ($i = 0; $i < @datafiles; $i++) {
	%service_info = &wizard_get_data("smfwizard_dependent.cgi", $i);
	# does sinst match?
	if ("$service_info{'sinst'}" eq "$sinst") {
		# add dep't
		if ($service_info{'dependent_stability'} eq "-") {
			$stability = "";
		} else {
			$stability =
		"<stability value='$service_info{'dependent_stability'}'/>";
			}
		@find_replace_array =
		    ("DEP_NAME/$service_info{'dependent_name'}",
		     "DEP_TYPE/$service_info{'dependent_type'}",
		     "DEP_GROUPING/$service_info{'dependent_grouping'}",
		     "DEP_RESTART_ON/$service_info{'dependent_restart_on'}",
	"DEP_FMRI/<service_fmri value=\'$service_info{'dependent_fmri'}\' />",
			"DEP_STABILITY/$stability");
		&fill_manifest_template("dependent_template.xml", $manifest,
			\@find_replace_array);
		}
	}
@datafiles = &list_wizard_datafiles("smfwizard_exec.cgi");
for ($i = 0; $i < @datafiles; $i++) {
	%service_info = &wizard_get_data("smfwizard_exec.cgi", $i);
	# does sinst match?
	if ("$service_info{'sinst'}" eq "$sinst") {
		# add exec method
		# method context
		if (("$service_info{'exec_user'}" =~ /.+/) ||
		    ("$service_info{'exec_group'}" =~ /.+/) ||
		    ("$service_info{'exec_privileges'}" =~ /.+/)) {
			$cred = "<method_context><method_credential ";
			if ("$service_info{'exec_user'}" =~ /.+/) {
				$cred =
				   "$cred user=\'$service_info{'exec_user'}\' ";
				}
			if ("$service_info{'exec_group'}" =~ /.+/) {
				$cred =
				 "$cred group=\'$service_info{'exec_group'}\' ";
				}
			if ("$service_info{'exec_privileges'}" =~ /.+/) {
				$cred =
			"$cred privileges=\'$service_info{'exec_privileges'}\' ";
				}
			$cred = "$cred /> </method_context>";
		} else {
			$cred = "";
			}
		@find_replace_array =
		    ("EXEC_NAME/$service_info{'exec_name'}",
		     "EXEC_TIMEOUT_SECONDS/$service_info{'exec_timeout'}",
		     "EXEC_EXEC/$service_info{'exec_exec'}",
		     "EXEC_METHOD_CREDENTIAL/$cred");
		&fill_manifest_template("exec_template.xml", $manifest,
			\@find_replace_array);
		}
	}
# for property group/properties, we cycle through property groups, then
# for each pgroup we see if each property is a member of the group AND
# applies at the appropriate service/instance level

@datafiles = &list_wizard_datafiles("smfwizard_property_group.cgi");
for ($i = 0; $i < @datafiles; $i++) {
	%service_info = &wizard_get_data("smfwizard_property_group.cgi", $i);
	$pgroup_name = "$service_info{'property_group_name'}";
	$pgroup_type = "$service_info{'property_group_type'}";
	if ($service_info{'property_group_stability'} eq "-") {
		$stability = "";
	} else {
		$stability =
	"<stability value='$service_info{'property_group_stability'}'/>";
		}
	@find_replace_array =
		("PGROUP_NAME/$pgroup_name", "PGROUP_TYPE/$pgroup_type",
		 "PGROUP_STABILITY/$stability");
	&fill_manifest_template("property_group_template.xml",
		$manifest, \@find_replace_array);
	@propfiles = &list_wizard_datafiles("smfwizard_property.cgi");
	for ($j = 0; $j < @propfiles; $j++) {
		# does sinst/pgroup match??
		%prop_info = &wizard_get_data("smfwizard_property.cgi", $j);
		if (("$sinst" eq "$prop_info{'sinst'}") &&
		    ("$pgroup_name" eq "$prop_info{'pgroup'}")) {
			# matched sinst/pgroup, display prop...
			@find_replace_array =
			    ("PROP_NAME/$prop_info{'property_name'}",
			     "PROP_TYPE/$prop_info{'property_type'}",
			     "PROP_VALUE/$prop_info{'property_value'}");
			&fill_manifest_template("property_template.xml",
				 $manifest, \@find_replace_array);
			}
		}
	@find_replace_array = ();
	&fill_manifest_template("property_group_template_end.xml", $manifest,
		\@find_replace_array);
	}
}

# subfunction to read in manifest template (for exec method, dependency
# etc), and replace keywords with desired values. the keywords/desired
# values are passed in as an array, each elt is a find/replace string.
# template values may be replace multiple times (e.g. service_fmris
# for deps
#
# Parameters: template_file target_file find_replace_arrayref
#
sub fill_manifest_template()
{
local ($template, $target, $find_replace_arrayref, @template_data,
	$find_replace_expr, @tdata, $find, $replace, $linenum, $line,
	@replace_data, $i);
($template, $target, $find_replace_arrayref) = @_;
open(TEMPLATE, "$module_root_directory/$template");
@template_data = <TEMPLATE>;
close(TEMPLATE);
foreach $find_replace_expr (@$find_replace_arrayref) {
	@tdata = @template_data;
	# split find/replace into components...
	$find_replace_expr =~ /([^\/]*)\/(.*)/;
	$find = $1;
	$replace = $2;
	$linenum = 0;
	foreach $line (@tdata) {
		if ($line =~ s/$find/$replace/) {
			$replace_data[$linenum] =
				"$replace_data[$linenum]$line\n";
			}
		$linenum++;
		}
	}
# now append to target file
if (-e $target) {
	open(TARGET, ">>$target");
} else {
	open(TARGET, ">$target");
	}
for ($i = 0; $i < @template_data; $i++) {
	# if we have a "replace" line, write it, otherwise write original
	# template line
	if ($replace_data[$i] =~ /.+/) {
		print TARGET "$replace_data[$i]";
	} else {
		print TARGET "$template_data[$i]";
		}
	}
close(TARGET);
}

# subroutines used in properties page

#
# subroutines used by dep_viewer page
#

# Builds dependency/dependent tree starting from fmri.
# Uses hash with fmris as keys to contain tree info. This way,
# we don't expand a particular branch multiple times when we recurse...
#
# Parameters: dependency_or_dependent, tree_ref, fmri, level, expand_listref
#
sub build_dep_tree()
{
local ($dependency_or_dependent, $tree_ref, $fmri, $level,
	$expand_listref, $state, $grouping, $allow_expand, $expand_fmri, $deps,
	@dep_info, $dep_inf, $dep_fmri, $dep_state, $parent, $child,
	$dep_grouping);
($dependency_or_dependent, $tree_ref, $fmri, $level, $expand_listref,
$state, $grouping) = @_;
$allow_expand = 0;
# if fmri is on expand list passed in, we allow expansion.
foreach $expand_fmri (@$expand_listref) {
	if ($expand_fmri eq $fmri) {
		$allow_expand = 1;
		break;
		}
	}
if ($tree_ref->{"$fmri"}->{'exists'} != 1) {
	# new hash element
	$tree_ref->{"$fmri"}->{'exists'} = 1;
	# state information, if passed in...
	if ($state =~ /.+/) {
		$tree_ref->{"$fmri"}->{'state'} = $state;
		}
	if ($grouping =~ /.+/) {
		$tree_ref->{"$fmri"}->{'grouping'} = $grouping;
		}
	# do we expand tree here (i.e. recurse?)
	$tree_ref->{"$fmri"}->{'expand'} = $allow_expand;
	@{$tree_ref->{"$fmri"}->{'children'}} = ();
	$tree_ref->{"$fmri"}->{'haschildren'} = 0;
	$deps = &svc_dep_cmd($dependency_or_dependent, $fmri);
	@dep_info = split(/\n/, $deps);
	foreach $dep_inf (@dep_info) {
		# dependency info consists of fmri and state
		$dep_inf =~ /(\S+)\s+(\S+)/;
		$dep_fmri = $1;
		$dep_state = $2;
		# we need to find out what grouping is (using svcs -l).
		# for dep'y we call svcs -l $fmri, looking for line
		# specifying $dep_fmri. for dep't we call svcs -l
		# $dep_fmri, looking for line specifying $fmri.
		if ($dependency_or_dependent eq "dependency") {
			$parent = $fmri;
			$child = $dep_fmri;
		} else {
			$parent = $dep_fmri;
			$child = $fmri;
			}
		$dep_grouping = &svc_grouping_cmd($parent, $child);
		# we need to determine if dep has children, in order
		# to disable the expand button if not. however, we
		# don't recurse if it does unless it was on expand list
		$tree_ref->{"$fmri"}->{'haschildren'} = 1;
		chomp($dep_fmri);
		push(@{$tree_ref->{"$fmri"}->{'children'}},
			$dep_fmri);
		if ($allow_expand == 1) {
			&build_dep_tree($dependency_or_dependent, $tree_ref,
				$dep_fmri, $level + 1, $expand_listref,
				$dep_state, $dep_grouping);
			}
		}	
	}
}

# Displays dependency/dependent tree using depth-first recursion:
# get fmris children, the print each childs children etc.
# However, if a fmri has expand == 0, we don`t recurse for it.
# For expanded fmris, we show the contract (-) button, and for
# unexpanded, we show the expand button (if they have children).
#
# Parameters: dependency_or_dependent, tree_ref, fmri, level
#
sub print_dep_tree()
{
local ($dependency_or_dependent, $tree_ref, $fmri, $level, $fmriinfo,
	$indent, $child_fmri, $tab, $i, $color);
($dependency_or_dependent, $tree_ref, $fmri, $level) = @_;
$fmriinfo = $fmri;
# indent according to level of tree
$indent = 8*$level;
$tab = "";
for ($i = 0; $i < $indent; $i++) {
	$tab="$tab&nbsp;";
	}
print "<p>$tab";
if ($tree_ref->{"$fmri"}->{'expand'} == 1) {
	$fmriinfo = &contractbutton($dependency_or_dependent, $tree_ref,
		$fmri);
} else {
	$fmriinfo = &expandbutton($dependency_or_dependent, $tree_ref,
		$fmri);
	}
# show expand/contract button...
if ($level > 0) {
	print "$fmriinfo";
	}
# apply-to checkbox
print "&nbsp;<input type=checkbox name=\"applyto\" value=\"$fmri\">\n";
# fmri, link to state editor page for fmri
print "&nbsp;<a href=\"dep_viewer.cgi?fmri='$fmri'\">$fmri</a>";
if ($tree_ref->{"$fmri"}->{'state'} =~ /.+/) {
	$color = "$state_colors{$tree_ref->{$fmri}->{'state'}}";
	print
	  "&nbsp;<font color=$color>$tree_ref->{$fmri}->{'state'}</font>";
	}
if ($tree_ref->{"$fmri"}->{'grouping'} =~ /.+/) {
	print "&nbsp;($tree_ref->{$fmri}->{'grouping'})";
	}
print "</p>\n";
if ($tree_ref->{"$fmri"}->{'expand'} == 1) {
	# we can expand
	foreach $child_fmri (@{$tree_ref->{"$fmri"}->{'children'}}) {
		&print_dep_tree($dependency_or_dependent, $tree_ref,
			$child_fmri, $level + 1);
		}
	}
}

sub contractbutton()
{
local ($dependency_or_dependent, $tree_ref, $fmri, $disable);
($dependency_or_dependent, $tree_ref, $fmri) = @_;
$disable = "";
# for elements with no children, disable button...
if ($tree_ref->{"$fmri"}->{'haschildren'} == 0) {
	$disable = "disabled=\"disabled\"";
	}
return "<input type=submit name=\"${dependency_or_dependent}_contract_$fmri\" value=\"-\" $disable><input type=\"hidden\" name=\"${dependency_or_dependent}_expandlist\" value=\"$fmri\">";
}

sub expandbutton()
{
local ($dependency_or_dependent, $tree_ref, $fmri, $disable);
($dependency_or_dependent, $tree_ref, $fmri) = @_;
$disable = "";
if ($tree_ref->{"$fmri"}->{'haschildren'} == 0) {
	$disable = "disabled=\"disabled\"";
	}
return "<input type=submit name=\"${dependency_or_dependent}_expand_$fmri\" value=\"+\" $disable>";
}


