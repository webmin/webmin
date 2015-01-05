#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# Save Postfix options


require './postfix-lib.pl';

&ReadParse();

$access{'general'} || &error($text{'opts_ecannot'});

#      &ui_print_header(undef, $text{'opts_title'}, "");


&error_setup($text{'opts_err'});

if (defined($in{"debug_peer_level_def"})) {
	$in{"debug_peer_level_def"} =~ /^[1-9]\d*$/ ||
		&error($text{'opts_edebug'});
	}

&lock_postfix_files();
&save_options(\%in);
&unlock_postfix_files();

$err = &reload_postfix();
&error($err) if ($err);

&webmin_log($in{'_log_form'} || "opts");
&redirect("");



