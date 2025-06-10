#!/usr/local/bin/perl

require './smf-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'smfwizard_title'}, "");

# wizard-specific info here
&wizard_header($wizard, "smfwizard_dependency.cgi",
	"$text{'smfwizard_dependency_heading'}",
	&convert_links_in_text("$text{'smfwizard_dependency_description'}"),
	"images/smf.gif");

@sinst_list = ("service");
# add existing instances to list...
@existing_insts = &wizard_get_data_values("smfwizard_instance.cgi",
	"instance_name");
@sinst_list= (@sinst_list, @existing_insts);
&wizard_select("smfwizard_dependency.cgi", "$text{'smfwizard_sinst_name'}",
	"sinst", \@sinst_list, ".+", "$text{'smfwizard_sinst_error'}");
&wizard_input("smfwizard_dependency.cgi", "$text{'smfwizard_dependency_name'}",
	"dependency_name", 60, ".+",
	"$text{'smfwizard_dependency_name_error'}");
&wizard_select("smfwizard_dependency.cgi", "$text{'smfwizard_dependency_type'}",
	"dependency_type", \@dep_types, ".+",
	"$text{'smfwizard_dependency_type_error'}");
&wizard_select("smfwizard_dependency.cgi",
	"$text{'smfwizard_dependency_grouping'}", "dependency_grouping",
	\@grouping_values, ".+",
	"$text{'smfwizard_dependency_grouping_error'}");
&wizard_select("smfwizard_dependency.cgi",
	"$text{'smfwizard_dependency_restart_on'}", "dependency_restart_on",
	\@restart_on_values, ".+",
	"$text{'smfwizard_dependency_restart_on_error'}");
&wizard_input("smfwizard_dependency.cgi",
	"$text{'smfwizard_dependency_fmri'}", "dependency_fmri",
	60, ".+", "$text{'smfwizard_dependency_fmri_error'}");
print "<tr $cb><td>";
&print_svc_chooser("dependency_fmri", 0, "$text{'svc_chooser_titleboth'}",
	"both", "0");
&print_path_chooser("dependency_fmri", 0, "$text{'path_chooser_title'}",
	"0");
print "</td></tr>";
&wizard_select("smfwizard_dependency.cgi",
	"$text{'smfwizard_dependency_stability'}", "dependency_stability",
	\@stability_values, ".+",
	"$text{'smfwizard_dependency_stability_error'}");

&wizard_footer($wizard, "smfwizard_dependency.cgi");
# end wizard-specific info

&ui_print_footer("index.cgi", $text{'index'});
