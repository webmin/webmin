#!/usr/local/bin/perl
# Show all global config options

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './fail2ban-lib.pl';
our (%in, %text);

my $conf = &get_config();
my ($def) = grep { $_->{'name'} eq 'Definition' } @$conf;
$def || &error($text{'config_edef'});

&ui_print_header(undef, $text{'config_title'}, "");

print &ui_form_start("save_config.cgi", "post");
print &ui_table_start($text{'config_header'}, undef, 2);

# Logging level
my $logsymbsupp = &compare_version_numbers(&get_fail2ban_version(), "0.9") >= 0;
my $loglevel = &find_value("loglevel", $def) || ($logsymbsupp ? "INFO" : 3);
my @loglevels;
if ($logsymbsupp) {
	@loglevels = ( "CRITICAL", "ERROR", "WARNING",
		       "NOTICE", "INFO", "DEBUG" );
	}
else {
	@loglevels = ( [ 1, "ERROR" ], [ 2, "WARN" ],
		       [ 3, "INFO" ], [ 4, "DEBUG" ] );
	}
print &ui_table_row($text{'config_loglevel'},
	&ui_select("loglevel", $loglevel, \@loglevels));

# Log file
my $logtarget = &find_value("logtarget", $def);
my $mode = $logtarget eq "" ? "" :
	   $logtarget =~ /^STDOUT|STDERR|SYSLOG$/ ? $logtarget : "file";
print &ui_table_row($text{'config_logtarget'},
		&ui_radio_row('logtarget_def', $mode,
		[ [ "", [ $text{'config_default'} ] ],
		  [ "STDOUT", [ "STDOUT" ] ],
		  [ "STDERR", [ "STDERR" ] ],
		  [ "SYSLOG", [ $text{'config_syslog'} ] ],
		  [ "file", [ $text{'config_file'},
		      &ui_textbox("logtarget",
				  $mode eq "file" ? $logtarget : "", 50) ] ]
		  ], 1));

# Socket file
my $socket = &find_value("socket", $def);
print &ui_table_row($text{'config_socket'},
	&ui_opt_textbox("socket", $socket, 40, $text{'default'}));

# DB Purge Age
if ($def) {
	my $dbpurgeage = &find_value("dbpurgeage", $def);
	$dbpurgeage ||= 86400;
	my @dbpurgeages = (
			[ '', '' ],
			[ '900', $text{'config_dbpurgeage_15m'} ],
			[ '1800', $text{'config_dbpurgeage_30m'} ],
			[ '3600', $text{'config_dbpurgeage_1h'} ],
			[ '21600', $text{'config_dbpurgeage_6h'} ],
			[ '43200', $text{'config_dbpurgeage_12h'} ],
			[ '86400', $text{'config_dbpurgeage_1d'} ],
			[ '259200', $text{'config_dbpurgeage_3d'} ],
			[ '604800', $text{'config_dbpurgeage_1w'} ],
			[ '1209600', $text{'config_dbpurgeage_2w'} ],
			[ '2629800', $text{'config_dbpurgeage_1mo'} ] );

	# Check of $dbpurgeage is in @dbpurgeages
	my $time_in_seconds = &time_to_seconds($dbpurgeage);
	my $dbpurgestd = grep { $_->[0] eq $time_in_seconds } @dbpurgeages;
	my $dbpurge_def = $time_in_seconds == 86400 ? 1 : $dbpurgestd ? 0 : 2;
	my $depurgeagelabeled = $dbpurge_def == 2
		? &seconds_to_time($dbpurgeage) 
		: undef;
	print &ui_table_row($text{'config_dbpurgeage'},
		&ui_radio_row('dbpurgeage', $dbpurge_def,
		[ [ 1, [ $text{'config_dbpurgeagedef'} ] ],
		  [ 0, [ $text{'config_dbpurgeagesel'},
		  	 &ui_select("dbpurgeagesel",
			 	$time_in_seconds, \@dbpurgeages) ] ],
		  [ 2, [ $text{'config_dbpurgeagecus'},
		  	&ui_textbox("dbpurgeagecus", $depurgeagelabeled, 15) ] ]
		]));
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
