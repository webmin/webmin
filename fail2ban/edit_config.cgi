#!/usr/local/bin/perl
# Show all global config options

use strict;
use warnings;
require './fail2ban-lib.pl';
our (%in, %text);

my $conf = &get_config();
my ($def) = grep { $_->{'name'} eq 'Definition' } @$conf;
$def || &error($text{'config_edef'});

&ui_print_header(undef, $text{'config_title'}, "");

print &ui_form_start("save_config.cgi", "post");
print &ui_table_start($text{'config_header'}, undef, 2);

# Logging level
my $loglevel = &find_value("loglevel", $def) || 3;
print &ui_table_row($text{'config_loglevel'},
	&ui_select("loglevel", $loglevel,
		   [ [ 1, "ERROR" ], [ 2, "WARN" ],
		     [ 3, "INFO" ], [ 4, "DEBUG" ] ]));

# Log file
my $logtarget = &find_value("logtarget", $def);
my $mode = $logtarget eq "" ? "" :
	   $logtarget =~ /^STDOUT|STDERR|SYSLOG$/ ? $logtarget : "file";
print &ui_table_row($text{'config_logtarget'},
	&ui_radio("logtarget_def", $mode,
		  [ [ "", $text{'config_default'}."<br>" ],
		    [ "STDOUT", "STDOUT<br>" ],
		    [ "STDERR", "STDERR<br>" ],
		    [ "SYSLOG", $text{'config_syslog'}."<br>" ],
		    [ "file", $text{'config_file'}." ".
		      &ui_textbox("logtarget",
				  $mode eq "file" ? $logtarget : "", 50) ]
		  ]));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
