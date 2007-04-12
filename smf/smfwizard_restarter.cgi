#!/usr/local/bin/perl

require './smf-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'smfwizard_title'}, "");

# wizard-specific info here
&wizard_header($wizard, "smfwizard_restarter.cgi",
	"$text{'smfwizard_restarter_heading'}",
	&convert_links_in_text("$text{'smfwizard_restarter_description'}"),
	"images/smf.gif");

&wizard_input("smfwizard_restarter.cgi",
	"$text{'smfwizard_restarter_fmri'}", "restarter_fmri",
	60, ".+", "$text{'smfwizard_restarter_fmri_error'}");

&wizard_footer($wizard, "smfwizard_restarter.cgi");
# end wizard-specific info

&ui_print_footer("index.cgi", $text{'index'});
