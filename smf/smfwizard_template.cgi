#!/usr/local/bin/perl

require './smf-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'smfwizard_title'}, "");

# wizard-specific info here
&wizard_header($wizard, "smfwizard_template.cgi",
	"$text{'smfwizard_template_heading'}",
	&convert_links_in_text("$text{'smfwizard_template_description'}"),
	"images/smf.gif");

&wizard_input("smfwizard_template.cgi",
	"$text{'smfwizard_template_common_name'}",
	"template_common_name", 60, ".+",
	"$text{'smfwizard_common_name_error'}");
&wizard_textarea("smfwizard_template.cgi",
	"$text{'smfwizard_template_svc_description'}", "template_description",
	10, 30, ".+", "$text{'smfwizard_template_svc_description_error'}");

&wizard_footer($wizard, "smfwizard_template.cgi");
# end wizard-specific info

&ui_print_footer("index.cgi", $text{'index'});
