#!/usr/local/bin/perl
# property_editor.cgi
# Display a list of properties for property group for fmri

require './smf-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'property_editor_title'}, "");

# get instance fmri
if (defined($in{'fmri'})) {
	$fmri = $in{'fmri'};
	# remove quotes...
	$fmri =~ /\'([^\']*)\'/;
	$fmri = $1;
	if ($fmri =~ /(svc:\/[^:]*):(.*)/) {
		$svc = $1;
		$inst = $2;
	} else {
		&error("Invalid fmri: instance must be specified!");
		}
} else {
	&error("No fmri supplied to property editor!");
	}
if (defined($in{'sinst'})) {
	$sinst = "$in{'sinst'}";
	$entity = ($sinst eq "service") ? "$svc" : "$svc:$inst";
} else {
	&error("Service/Instance level not specified for property editor!");
	}
if (defined($in{'pgroup'})) {
	$pgroup = $in{'pgroup'};
} else {
	&error("No property group supplied to property editor!");
	}

# deal with add/deletion/update of properties first. this way
# prop list will show changes...
if ((defined($in{'add'})) &&
    (defined($in{'addname'})) &&
    (defined($in{'addtype'})) &&
    (defined($in{'addvalue'}))) {
	$addname = "$in{'addname'}";
	$addtype = "$in{'addtype'}";
	$addvalue = "$in{'addvalue'}";
	if (($addname =~ /.+/) && ($addtype =~ /.+/) && ($addvalue =~ /.+/)) {
		&svc_setprop("$svc", "$sinst", "$pgroup", "$addname",
			"$addtype", "$addvalue");
		}
	}
if (defined($in{'remove'})) {
	# get remove prop list
	@remove_props = split(/\0/, $in{'applyto'});
	foreach $rp (@remove_props) {
		&svc_delprop("$svc", "$sinst", "$pgroup", "$rp");
		}
	}
@prop_listing = &svc_listprop("$svc", "$sinst", $pgroup);

# need prop listing to match against values for update. if we change
# anything, we`ll regenerate the listing...
$regenerate_listing = 0;
if (defined($in{'update'})) {
	# update each prop in listing with new value
	foreach $prop (@prop_listing) {
		$prop_name = $prop->{'prop_name'};
		$prop_type = $prop->{'prop_type'};
		if (defined($in{"$prop_name/$prop_type"})) {
			$prop_value = $in{"$prop_name/$prop_type"};
			&svc_setprop("$svc", "$sinst", "$pgroup", "$prop_name",
				"$prop_type", "$prop_value");
			$regenerate_listing = 1;
			}
		}
	}
if ($regenerate_listing == 1) {
	@prop_listing = &svc_listprop("$svc", "$sinst", $pgroup);
	}

print "<h2>";
&text_and_whats_this("property_editor_detail");
print " : $entity/$pgroup</h2>\n";

print "<form method=\"POST\" action=\"property_editor.cgi?fmri='$fmri'&sinst=$sinst&pgroup=$pgroup\">\n";

# add prop table first...
print "<p><h3>$text{'property_editor_addprop'}</h3>\n";
print "<table><tr>";
print "<td><b>$text{'property_editor_addname'}</b></td>\n";
print "<td><b>$text{'property_editor_addtype'}</b></td>\n";
print "<td><b>$text{'property_editor_addvalue'}</b></td></tr>\n";
print "<tr><td>\n";
print "<input size=30 name=\"addname\" value=\"\">\n";
print "</td><td>\n";
&print_selection("addtype", "", \@propval_type_values);
print "</td><td>\n";
print "<input size=60 name=\"addvalue\" value=\"\">\n";
print "</td></tr>\n";
print "<tr><td>&nbsp;</td><td>&nbsp;</td><td>";
print "<input type=submit name=\"add\" value=\"$text{'property_editor_add'}\">\n";
print "</td></tr></table></b>\n";

print "<table border width=100%>\n";
print "<tr><td><table width=100%>\n";
print "<tr $cb><td><b>$text{'property_editor_apply'}</b>:&nbsp;";
print "<input type=submit name=\"remove\" onClick=\"return (confirm(\'$text{'property_editor_deleteconfirm'}\'))\" value=\"$text{'property_editor_delete'}\">&nbsp;\n";
print "</td></tr></table></td></tr>\n";
print "<tr><td><table width=100%>\n";
print "<tr $cb>\n";
print "<td><b>$text{'property_editor_select'}</b></td>\n";
print "<td><b>$text{'property_editor_prop_name'}</b></td>\n";
print "<td><b>$text{'property_editor_prop_type'}</b></td>\n";
print "<td><b>$text{'property_editor_prop_value'}</b></td></tr>\n";

foreach $prop (@prop_listing) {
	print "<tr $cb>";
	$name = $prop->{'prop_name'};
	$type = $prop->{'prop_type'};
	$value = $prop->{'prop_value'};
	print "<td>\n";
	print "<input type=checkbox name=\"applyto\" value=\"$name\">";
	print "</td>\n";
	print "<td>$name</td>\n";
	print "<td>$type</td>\n";
	print
	    "<td><input size=60 name=\"$name/$type\" value=\"$value\"></td>\n";
	print "</tr>\n";
}
print "<tr $cb><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>\n";
print
"<input type=submit name=\"update\" value=\"$text{'property_editor_update'}\">";
print "</td></tr>\n";
print "</table></td></tr></table></form>\n";

&print_cmds_run();

&ui_print_footer("property_group_editor.cgi?fmri='$fmri'",
	$text{'property_editor_back'});

