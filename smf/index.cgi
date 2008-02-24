#!/usr/local/bin/perl
# index.cgi
# Display a list of services, built from svcs command

$unsafe_index_cgi = 1;
require './smf-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'index_title'}, "", "help", 1, 1, 0,
	&help_search_link("smf", "man", "doc", "howto"));

# deal with application of state changes first. this way
# fmri list will show changes...
if (defined($in{'change_state'})) {
	$cmd = "$in{'change_state'}";
	# get update fmri list
	@update_fmris = split(/\0/, $in{'applyto'});
	&svc_state_cmd("$cmd", \@update_fmris);
	}

# service type
if (defined($in{'type'})) {
	$svc_type = $in{'type'};
} else {
	$svc_type = "All";
	}
if (defined($in{'include_disabled'})) {
	$include_disabled = $in{'include_disabled'};
} else {
	$include_disabled = $default_include_disabled;
	}
if ($include_disabled == 1) {
	$checked_include_disabled = "checked";
} else {
	$checked_include_disabled = "";
	}
# opts for svcs listing
$opts = "$default_svc_options";

if (defined($in{'opts'})) {
	@extraopts = split(/\0/, $in{'opts'});
	foreach $extraopt (@extraopts) {
		$opts = "$opts,$extraopt";
		}
	}
$sortopt = "$default_sortopt";
if (defined($in{'sortopt'})) {
	$sortopt = $in{'sortopt'};
	}

print "<h2>";
&text_and_whats_this("index_detail");
print "</h2>\n";
# Checkboxes for view update
print "<form method=\"POST\" action=\"index.cgi\">\n";
print "<p><table>\n";
print "<tr><td><b>$text{'index_svc_type'}</b></td>\n";
print "<td>";
@typelist = sort keys %svc_types;
&print_selection("type", "$svc_type", \@typelist);
print "</td></tr>\n";
print "<tr><td><b>$text{'index_extraopts'}</b></td>\n";
print "</b></td>\n";
print "<td>";
@additional_option_names = sort keys %svc_options;
foreach $o (@additional_option_names) {
	if ($default_svc_options =~ /$o/) {
		next;
		}
	$checked = "unchecked";
	if ($opts=~ /$o/) {
		$checked = "checked";
		$opts_str="$opts_str\&opts=$o";
		}
	print "$svc_options{$o}";
	print "<input type=checkbox name=\"opts\" value=\"$o\" $checked>&nbsp;";
	}
print "</td></tr>\n";
print "<tr><td><b>$text{'index_include_disabled'}</b></td>\n";
print "<td>";
print
"<input type=checkbox name=\"include_disabled\" value=1 $checked_include_disabled>";
print "</td></tr>\n";
print "<tr><td>&nbsp;</td><td>\n";
print "<input type=submit name=\"submit\" value=\"Update View\"/></td></tr>";
print "</table></p></form>\n";

print "<form method=\"POST\" action=\"index.cgi?include_disabled=$include_disabled&type=$svc_type&sortopt=$sortopt$opts_str\">\n";

print "<table border width=100%>\n";
print "<tr><td><table width=100%>\n";
# multiple select buttons(enable, disable, maintenance, degraded, clear, delete)
print "<tr $cb><td>\n";
print "<input type=\"button\" onClick=location.href=\"smfwizard_service.cgi?clearout=1\" value=\"$text{'index_create_new_service'}\">";
print "&nbsp;";
print "<input type=\"button\" onClick=location.href=\"search_instance.cgi\" value=\"$text{'index_search_instance'}\">\n";
print "</td></tr><tr $cb><td><b>$text{'index_apply'}</b>:&nbsp;";
&print_state_buttons();
# add delete/create new buttons in addition to statechange buttons
print "<input type=submit name=\"change_state\" onClick=\"return (confirm(\'$text{'index_deleteconfirm'}\'))\" value=\"$text{'index_delete'}\">&nbsp;\n";
print "</td></tr></table></td></tr>\n";
print "<tr><td><table width=100%>\n";
@svcs_info = &svcs_listing("$svc_types{$svc_type}", "$sortopt");
@optlist = split(/,/, $opts);
print "<tr $cb>\n";
print "<td>$text{'index_select'}</td>\n";
foreach $o (@optlist) {
	# clicking should reverse sort option if we`re already sorting by
	# this option...
	if ($sortopt =~/-S$o/) {
		$new_sortopt = "-s$o";
	} elsif ($sortopt =~/-s$o/) {
		$new_sortopt = "-S$o";
	} else {
		$new_sortopt = "-s$o";
		}
	print "<td>";
	print "$text{'index_sort_by'}:&nbsp;";
	print "<a href=\"index.cgi?include_disabled=$include_disabled&type=$svc_type&sortopt=$new_sortopt$opts_str\">";
	print "$svc_options{$o}</a></td>\n";
	}
print "</tr>\n";

for $svc_info (@svcs_info) {
	# if we are displaying enabled only, skip disabled
	if (($include_disabled != 1) && ($svc_info->{'STATE'} eq "disabled")) {
		next;
		}
	print "<tr $cb>";
	$fmri = $svc_info->{'FMRI'};
	if ("$fmri" =~ /^lrc:\//) {
		print "<td>-</td>\n";
	} else {
		print "<td><input type=checkbox name=\"applyto\" value=\"$svc_info->{'FMRI'}\"></td>\n";
		}
        foreach $opt (@optlist) {
		$field = $svc_info->{$opt};
		if ($opt eq "FMRI") {
			$field =~ /$svc_types{$svc_type}(.*)/;
			$svc = $1;
			# make sure legacy svcs are unclickable!
			if ($field =~ /svc:\//) {
				print "<td>";
				print
		"<a href=\"instance_viewer.cgi?fmri='$fmri'\">$svc</a>";
				print "</td>\n";
			} else {
				print "<td>$svc</td>\n";
				}
		} elsif ($opt eq "STATE") {
			print
			    "<td>";
			print
    "<font color=$state_colors{$svc_info->{$opt}}>$svc_info->{$opt}</font>\n";
			print "</td>\n";
		} else {
			print "<td>$field</td>"
		}
	}
	print "</tr>\n";
}
print "</table></td></tr></table></form>\n";

&print_cmds_run();

&ui_print_footer("/", $text{'index'});

