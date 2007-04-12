#!/usr/local/bin/perl

require './smf-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'smfwizard_title'}, "");

# wizard-specific info here
&wizard_header($wizard, "smfwizard_exec.cgi",
	"$text{'smfwizard_exec_heading'}",
	&convert_links_in_text("$text{'smfwizard_exec_description'}"),
	"images/smf.gif");

@sinst_list = ("service");
# add existing instances to list...
@existing_insts = &wizard_get_data_values("smfwizard_instance.cgi",
	"instance_name");
@sinst_list= (@sinst_list, @existing_insts);

&wizard_select("smfwizard_exec.cgi", "$text{'smfwizard_sinst_name'}",
	"sinst", \@sinst_list, ".+", "$text{'smfwizard_sinst_error'}");
&wizard_input("smfwizard_exec.cgi", "$text{'smfwizard_exec_name'}",
	"exec_name", 60, ".+",
	"$text{'smfwizard_exec_name_error'}");
&wizard_input("smfwizard_exec.cgi", "$text{'smfwizard_exec_timeout'}",
	"exec_timeout", 20, "[0-9]+",
	"$text{'smfwizard_exec_timeout_error'}");
&wizard_input("smfwizard_exec.cgi",
	"$text{'smfwizard_exec_exec'}", "exec_exec",
	60, ".+", "$text{'smfwizard_exec_exec_error'}");
&wizard_input("smfwizard_exec.cgi",
	"$text{'smfwizard_exec_user'}", "exec_user",
	60, ".*", "$text{'smfwizard_exec_user_error'}");
&wizard_input("smfwizard_exec.cgi",
	"$text{'smfwizard_exec_group'}", "exec_group",
	60, ".*", "$text{'smfwizard_exec_group_error'}");
&wizard_input("smfwizard_exec.cgi",
	"$text{'smfwizard_exec_privileges'}", "exec_privileges",
	60, ".*", "$text{'smfwizard_exec_privileges_error'}");

&wizard_footer($wizard, "smfwizard_exec.cgi");
# end wizard-specific info

&ui_print_footer("index.cgi", $text{'index'});
