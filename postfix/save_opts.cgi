#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# Save Postfix options


require './postfix-lib.pl';    ## no critic
use strict;
use warnings;
our ($err, %access, %in, %text);

&ReadParse();

my $section = $in{'_log_form'} eq 'local' ? 'local_delivery' :
	      $in{'_log_form'} eq 'opts' ? 'address_rewriting' : $in{'_log_form'};
my $options = &options_for_section($section);
$options && $section ne 'general' && $access{$section} || &error($text{'opts_ecannot'});

&error_setup($text{'opts_err'});

if (defined($in{"debug_peer_level_def"})) {
	$in{"debug_peer_level_def"} =~ /^[1-9]\d*$/ ||
		&error($text{'opts_edebug'});
	}
if (defined($in{"inet_protocols"})) {
	$in{'inet_protocols_def'} = $in{'inet_protocols'} ||
		"__DEFAULT_VALUE_IE_NOT_IN_CONFIG_FILE__";
	}

&lock_postfix_files();
&save_options(\%in, [ "inet_protocols" ], $options);
&unlock_postfix_files();

$err = &reload_postfix();
&error($err) if ($err);

&webmin_log($in{'_log_form'} || "opts");
&redirect("");



