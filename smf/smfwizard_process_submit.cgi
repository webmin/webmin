#!/usr/local/bin/perl

require './smf-lib.pl';
&ReadParse();

# wizard-specific info here
&wizard_process_submit($wizard);

# all other options result in a redirect, but here we place
# code to handle "Finish").
$manifest = "$module_config_directory/manifest.xml";
&create_smf_manifest($manifest);
&svc_import($manifest);
# end wizard-specific info

&redirect("");
