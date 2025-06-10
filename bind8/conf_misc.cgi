#!/usr/local/bin/perl
# conf_misc.cgi
# Display miscellaneous options
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
# Globals
our (%access, %text);

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'misc_ecannot'});
&ui_print_header(undef, $text{'misc_title'}, "",
		 undef, undef, undef, undef, &restart_links());

&ReadParse();
my $conf = &get_config();
my $options = &find("options", $conf);
my $mems = $options->{'members'};

# Start of the form
print &ui_form_start("save_misc.cgi", "post");
print &ui_table_start($text{'misc_header'}, "width=100%", 4);

print &opt_input($text{'misc_core'}, 'coresize', $mems, $text{'default'}, 8);
print &opt_input($text{'misc_data'}, 'datasize', $mems, $text{'default'}, 8);

print &opt_input($text{'misc_files'}, 'files', $mems, $text{'default'}, 8);
print &opt_input($text{'misc_stack'}, 'stacksize', $mems, $text{'default'}, 8);

print &ui_table_hr();

print &opt_input($text{'misc_clean'}, 'cleaning-interval', $mems,
		 $text{'default'}, 8, "$text{'misc_mins'}");
print &opt_input($text{'misc_iface'}, 'interface-interval', $mems,
		 $text{'default'}, 8, "$text{'misc_mins'}");

print &opt_input($text{'misc_stats'}, 'statistics-interval', $mems,
		 $text{'default'}, 8, "$text{'misc_mins'}");

print &ui_table_hr();

print &choice_input($text{'misc_recursion'}, 'recursion', $mems,
		    $text{'yes'}, 'yes', $text{'no'}, 'no',
		    $text{'default'}, undef);
print &choice_input($text{'misc_cnames'}, 'multiple-cnames', $mems,
		    $text{'yes'}, 'yes', $text{'no'}, 'no',
		    $text{'default'}, undef);

print &choice_input($text{'misc_glue'}, 'fetch-glue', $mems,
		    $text{'yes'}, 'yes', $text{'no'}, 'no',
		    $text{'default'}, undef);
print &choice_input($text{'misc_nx'}, 'auth-nxdomain', $mems,
		    $text{'yes'}, 'yes', $text{'no'}, 'no',
		    $text{'default'}, undef);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});


