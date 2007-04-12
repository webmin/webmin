#!/usr/local/bin/perl

require './smf-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'smfwizard_title'}, "");

# wizard-specific info here!

if (defined($in{'clearout'})) {
	if ($in{'clearout'} == 1) {
		&wizard_clear_all_data($wizard);
		}
	}
&wizard_header($wizard, "smfwizard_service.cgi",
	"$text{'smfwizard_service_heading'}",
	&convert_links_in_text("$text{'smfwizard_service_description'}"),
	"images/smf.gif");
&wizard_input("smfwizard_service.cgi", "$text{'smfwizard_service_name'}",
	"service_name", 60, ".+", "$text{'smfwizard_service_name_error'}");
&wizard_input("smfwizard_service.cgi", "$text{'smfwizard_service_version'}",
	"service_version", 60, "\s*[0-9]+\s*",
	"$text{'smfwizard_service_version_error'}");

&wizard_footer($wizard, "smfwizard_service.cgi");
# end wizard-specific info

&ui_print_footer("index.cgi", $text{'index'});

