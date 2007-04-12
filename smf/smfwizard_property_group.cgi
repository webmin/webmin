#!/usr/local/bin/perl

require './smf-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'smfwizard_title'}, "");

# wizard-specific info here
&wizard_header($wizard, "smfwizard_property_group.cgi",
	"$text{'smfwizard_property_group_heading'}",
	&convert_links_in_text("$text{'smfwizard_property_group_description'}"),
	"images/smf.gif");

&wizard_input("smfwizard_property_group.cgi",
	"$text{'smfwizard_property_group_name'}",
	"property_group_name", 60, ".+",
	"$text{'smfwizard_property_group_name_error'}");
&wizard_input("smfwizard_property_group.cgi",
	"$text{'smfwizard_property_group_type'}", "property_group_type",
	60, ".+", "$text{'smfwizard_property_group_type_error'}");
&wizard_select("smfwizard_property_group.cgi",
	"$text{'smfwizard_property_group_stability'}",
	"property_group_stability",
	\@stability_values, ".+",
	"$text{'smfwizard_property_group_stability_error'}");

&wizard_footer($wizard, "smfwizard_property_group.cgi");
# end wizard-specific info

&ui_print_footer("index.cgi", $text{'index'});
