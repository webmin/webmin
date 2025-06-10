#!/usr/local/bin/perl

require './smf-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'smfwizard_title'}, "");

# wizard-specific info here
&wizard_header($wizard, "smfwizard_property.cgi",
	"$text{'smfwizard_property_heading'}",
	&convert_links_in_text("$text{'smfwizard_property_description'}"),
	"images/smf.gif");

@sinst_list = ("service");
# add existing instances to list...
@existing_insts = &wizard_get_data_values("smfwizard_instance.cgi",
	"instance_name");
@sinst_list= (@sinst_list, @existing_insts);
@pgroup_list = &wizard_get_data_values("smfwizard_property_group.cgi",
	"property_group_name");
&wizard_select("smfwizard_property.cgi", "$text{'smfwizard_sinst_name'}",
	"sinst", \@sinst_list, ".+", "$text{'smfwizard_sinst_error'}");
&wizard_select("smfwizard_property.cgi", "$text{'smfwizard_pgroup_name'}",
	"pgroup", \@pgroup_list, ".+", "$text{'smfwizard_pgroup_name_error'}");

&wizard_input("smfwizard_property.cgi",
	"$text{'smfwizard_property_name'}",
	"property_name", 60, ".+",
	"$text{'smfwizard_property_name_error'}");
&wizard_select("smfwizard_property.cgi",
	"$text{'smfwizard_property_type'}",
	"property_type", \@propval_type_values, ".+",
	"$text{'smfwizard_property_type_error'}");
&wizard_input("smfwizard_property.cgi",
	"$text{'smfwizard_property_value'}", "property_value",
	60, ".*", "$text{'smfwizard_property_value_error'}");

&wizard_footer($wizard, "smfwizard_property.cgi");
# end wizard-specific info

&ui_print_footer("index.cgi", $text{'index'});
