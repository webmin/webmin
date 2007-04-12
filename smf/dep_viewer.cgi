#!/usr/local/bin/perl
# dependency/dependent tree viewer
# Display a form for displaying/editing SMF service states in dependency
# and dependent trees.

require './smf-lib.pl';
&ReadParse();

# get instance fmri
if (defined($in{'fmri'})) {
	$fmri = $in{'fmri'};
	# remove quotes...
	$fmri =~ /\'([^\']*)\'/;
	$fmri = $1;
} else {
	&error("No fmri supplied to dep viewer!");
	}

# deal with application of state changes first. this way
# dep lists will show new states...
if (defined($in{'change_state'})) {
	$cmd = "$in{'change_state'}";
	# get update fmri list
	@update_fmris = split(/\0/, $in{'applyto'});
	&svc_state_cmd("$cmd", \@update_fmris);
	}

@depy_expand_list = ();
# which dependency fmris do we expand?
if (defined($in{'dependency_expandlist'})) {
	# get required expansions. each is fmri
	@depy_expand_list = split(/\0/, $in{'dependency_expandlist'});
	}
# Expand list - list of fmris to expand. By default, expand top fmri.
push(@depy_expand_list, $fmri);

@dept_expand_list = ();
# which dependent fmris do we expand?
if (defined($in{'dependent_expandlist'})) {
	# get required expansions. each is fmri
	@dept_expand_list = split(/\0/, $in{'dependent_expandlist'});
	}
# Expand list - list of fmris to expand. By default, expand top fmri.
push(@dept_expand_list, $fmri);

# get new expansion/contractions submitted...
@inkeys = keys(%in);
foreach $inkey (@inkeys) {
	if ($inkey =~ /dependency_expand_(.*)$/) {
		$expand_fmri = $1;
		push(@depy_expand_list, $expand_fmri);
		}
	if ($inkey =~ /dependency_contract_(.*)$/) {
		$contract_fmri = $1;
		foreach $e (@depy_expand_list) {
			$old = shift(@depy_expand_list);
			if ($old eq $contract_fmri) {
				next;
				}
			push(@depy_expand_list, $old);
			}
		}
	if ($inkey =~ /dependent_expand_(.*)$/) {
		$expand_fmri = $1;
		push(@dept_expand_list, $expand_fmri);
		}
	if ($inkey =~ /dependent_contract_(.*)$/) {
		$contract_fmri = $1;
		foreach $e (@dept_expand_list) {
			$old = shift(@dept_expand_list);
			if ($old eq $contract_fmri) {
				next;
				}
			push(@dept_expand_list, $old);
			}
		}
	}

# Gather service description, and state info
$description = &run_smf_cmds("/usr/bin/svcs -H -oDESC $fmri", 0);

%depy_tree = ();
%dept_tree = ();
$depy_treeref = \%depy_tree;
$dept_treeref= \%dept_tree;
$instance_state = &svc_get_state_cmd($fmri);
&build_dep_tree("dependent", $dept_treeref, $fmri, 0, \@dept_expand_list,
	$instance_state);
&build_dep_tree("dependency", $depy_treeref, $fmri, 0, \@depy_expand_list,
	$instance_state);

&ui_print_header(undef, $text{'dep_viewer_title'}, "", undef);

print "<form method=\"POST\" action=\"dep_viewer.cgi?fmri='$fmri'\">\n";

print "<h2>$description</h2>\n";
print "<h2>";
&text_and_whats_this("dep_viewer_detail");
print "</h2>";

print "<h2>$text{'dep_viewer_depy_info'}</h2>\n";
print "<p>$text{'dep_viewer_apply'}:&nbsp\n";
&print_state_buttons();
print "</p>\n";
&print_dep_tree("dependency", $depy_treeref, $fmri, 0, \@depy_expand_list);

print "<h2>$text{'dep_viewer_dept_info'}</h2>\n";
print "<p>$text{'dep_viewer_apply'}:&nbsp\n";
&print_state_buttons();
print "</p>\n";
&print_dep_tree("dependent", $dept_treeref, $fmri, 0, \@dept_expand_list);

print "</form>\n";

&print_cmds_run();

&ui_print_footer("instance_viewer.cgi?fmri='$fmri'",
        $text{'dep_viewer_back'});
