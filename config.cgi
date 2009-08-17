#!/usr/local/bin/perl
# config.cgi
# Display a form for editing the configuration of a module.

BEGIN { push(@INC, ".."); };
use WebminCore;
require './config-lib.pl';
&init_config();
&ReadParse();
$m = $in{'module'} || $ARGV[0];
&foreign_available($m) || &error($text{'config_eaccess'});
%access = &get_module_acl(undef, $m);
$access{'noconfig'} &&
	&error($text{'config_ecannot'});
%module_info = &get_module_info($m);
if (-r &help_file($m, "config_intro")) {
	$help = [ "config_intro", $m ];
	}
else {
	$help = undef;
	}
&ui_print_header(&text('config_dir', $module_info{'desc'}),
		 $text{'config_title'}, "", $help, 0, 1);

print &ui_form_start("config_save.cgi", "post");
print &ui_hidden("module", $m),"\n";
print &ui_table_start(&text('config_header', $module_info{'desc'}),
		      "width=100%", 2);
&read_file("$config_directory/$m/config", \%newconfig);

$mdir = &module_root_directory($m);
if (-r "$mdir/config_info.pl") {
	# Module has a custom config editor
	&foreign_require($m, "config_info.pl");
	local $fn = "${m}::config_form";
	if (defined(&$fn)) {
		$func++;
		&foreign_call($m, "config_form", \%newconfig);
		}
	}
if (!$func) {
	# Use config.info to create config inputs
	&generate_config(\%newconfig, "$mdir/config.info", $m);
	}
print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("/$m", $text{'index'});

