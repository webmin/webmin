#!/usr/local/bin/perl
# conf_files.cgi
# Display global files options
use strict;
use warnings;
# Globals
our (%access, %text);

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'files_ecannot'});
&ui_print_header(undef, $text{'files_title'}, "",
		 undef, undef, undef, undef, &restart_links());

&ReadParse();
my $conf = &get_config();
my $options = &find("options", $conf);
my $mems = $options->{'members'};

# Start of the form
print &ui_form_start("save_files.cgi", "post");
print &ui_table_start($text{'files_header'}, "width=100%", 4);

print &opt_input($text{'files_stats'}, "statistics-file", $mems,
		 $text{'default'}, 40, &file_chooser_button("statistics_file"));

print &opt_input($text{'files_dump'}, "dump-file", $mems,
		 $text{'default'}, 40, &file_chooser_button("dump_file"));

print &opt_input($text{'files_pid'}, "pid-file", $mems,
		 $text{'default'}, 40, &file_chooser_button("pid_file"));

print &opt_input($text{'files_xfer'}, "named-xfer", $mems,
		 $text{'default'}, 40, &file_chooser_button("named_xfer"));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

