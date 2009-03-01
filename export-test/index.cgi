#!/usr/local/bin/perl

do 'export-test-lib.pl';
$module_index_name = "Click me";
&ui_print_header(undef, "Export Test", "");

print "First module $module_name<p>\n";
&foreign_require("export-call");
&export_call::print_stuff();
print "Back in $module_name<p>\n";

print "Config directory $config_directory<p>\n";

print "This module from get_module_name is ",&get_module_name(),"<p>\n";

print "Foreign module is $export_call::module_name<p>\n";

print "Test of config = $config{'foo'}<p>\n";
$config{'foo'} = int(rand()*1000000);
&save_module_config();

%access = &get_module_acl();
print "ACL test = $access{'smeg'}<p>\n";

print $text{'my_msg'},"<p>\n";
print &text('my_subs', 'Jamie'),"<p>\n";

&export_call::print_text();

&export_call::die_now();

&ui_print_footer("/", $text{'index'});

