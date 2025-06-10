#!/usr/local/bin/perl

require './smf-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'smfwizard_title'}, "");

# wizard-specific info here
&wizard_header($wizard, "smfwizard_instance.cgi",
	"$text{'smfwizard_instance_heading'}",
	&convert_links_in_text("$text{'smfwizard_instance_description'}"),
	"images/smf.gif");
&wizard_input("smfwizard_instance.cgi", "$text{'smfwizard_instance_name'}",
	"instance_name", 60, ".+", "$text{'smfwizard_instance_name_error'}");
&wizard_select("smfwizard_instance.cgi", "$text{'smfwizard_instance_enabled'}",
	"instance_enabled", \@boolean_values, ".+",
	"$text{'smfwizard_instance_enabled_error'}");

&wizard_footer($wizard, "smfwizard_instance.cgi");
# end wizard-specific info

&ui_print_footer("index.cgi", $text{'index'});

