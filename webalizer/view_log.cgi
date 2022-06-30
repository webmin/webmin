#!/usr/local/bin/perl
# view_log.cgi
# Display the report for some log file

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %config, %gconfig, %access, $module_name, %in, $remote_user);
require './webalizer-lib.pl';
&ReadParse();

my ($escaped, $file, $log);
if ($ENV{'PATH_INFO'} =~ /^\/([^\/]+)(\/[^\/]*)$/) {
	# Proper path escaping
	$escaped = $1;
	$file = $2;
	$log = &un_urlize($escaped);
	}
elsif ($ENV{'PATH_INFO'} =~ /^(\/.*)(\/[^\/]*)$/) {
	# Path has been decode somehow, perhaps by proxy.. deal
	$log = $1;
	$file = $2;
	}
else {
	&error($text{'view_epath'});
	}

$file =~ /\.\./ || $file =~ /\<|\>|\||\0/ && &error($text{'view_efile'});
&can_edit_log($log) || &error($text{'view_ecannot'});

my $lconf = &get_log_config($log) || &error($text{'view_elog'}." : $log");
my $full = $lconf->{'dir'}.$file;
my $fh;
my $data = &eval_as_unix_user($lconf->{'user'} || 'root',
		sub { &read_file_contents($full) });
$data || &error($text{'view_eopen'}." : $full");

# Display file contents
if ($full =~ /\.(html|htm)$/i && !$config{'naked'}) {
	$data =~ /<TITLE>(.*)<\/TITLE>/i;
	my $title = $1;
	$data =~ s/^[\000-\377]*<BODY.*>//i;
	$data =~ s/<\/BODY>[\000-\377]*$//i;

	&ui_print_header(undef, $title || $text{'view_title'}, "");
	print $data;
	if ($access{'view'}) {
		&ui_print_footer("", $text{'index_return'});
		}
	else {
		&ui_print_footer(
			 "/$module_name/edit_log.cgi?file=$escaped",
			$text{'edit_return'},
			"", $text{'index_return'});
		}
	}
else {
	print "Content-type: ",$full =~ /\.png$/i ? "image/png" :
			       $full =~ /\.gif$/i ? "image/gif" :
			       $full =~ /\.(jpg|jpeg)$/i ? "image/jpeg" :
			       $full =~ /\.(html|htm)$/i ? "text/html" :
							   "text/plain","\n";
	print "\n";
	print $data;
	}

