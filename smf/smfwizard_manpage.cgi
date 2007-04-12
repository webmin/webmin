#!/usr/local/bin/perl

require './smf-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'smfwizard_title'}, "");

# wizard-specific info here
&wizard_header($wizard, "smfwizard_manpage.cgi",
	"$text{'smfwizard_manpage_heading'}",
	&convert_links_in_text("$text{'smfwizard_manpage_description'}"),
	"images/smf.gif");

&wizard_input("smfwizard_manpage.cgi",
	"$text{'smfwizard_manpage_title'}",
	"manpage_title", 60, ".+",
	"$text{'smfwizard_manpage_title_error'}");
&wizard_input("smfwizard_manpage.cgi",
	"$text{'smfwizard_manpage_section'}",
	"manpage_section", 10, ".+",
	"$text{'smfwizard_manpage_section_error'}");
&wizard_input("smfwizard_manpage.cgi",
	"$text{'smfwizard_manpage_manpath'}",
	"manpage_manpath", 60, ".+",
	"$text{'smfwizard_manpage_manpath_error'}");

&wizard_footer($wizard, "smfwizard_manpage.cgi");
# end wizard-specific info

&ui_print_footer("index.cgi", $text{'index'});
