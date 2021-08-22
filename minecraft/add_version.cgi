#!/usr/local/bin/perl
# Upload or download a new JAR

use strict;
use warnings;
require './minecraft-lib.pl';
our (%in, %text, %config);
&error_setup($text{'versions_err'});
&ReadParseMime();

# Get the file
my $temp = &transname();
my $origfile;
if ($in{'mode'} == 0) {
	# Download the file
	$in{'url'} || &error($text{'versions_eurl'});
	my ($host, $port, $page, $ssl) = &parse_http_url($in{'url'});
	$host || &error($text{'versions_eurl2'});
	my $err;
	&http_download($host, $port, $page, $temp, \$err, undef, $ssl);
	$err && &error($err);
	$origfile = $page;
	}
else {
	# Use uploaded file
	$in{'jar'} || &error($text{'versions_ejar'});
	$in{'jar_filename'} || &error($text{'versions_ejar2'});
	my $fh = "JAR";
	&open_tempfile($fh, ">$temp", 0, 1);
	&print_tempfile($fh, $in{'jar'});
	&close_tempfile($fh);
	$origfile = $in{'jar_filename'};
	}

# Work out the filename to upload as
my $dir = $config{'minecraft_dir'};
my $ver;
my $dest;
if ($in{'newver_def'}) {
	$origfile =~ s/^.*[\/\\]//;
	$origfile =~ /([0-9\.]+)\.jar$/ || &error($text{'versions_ever'});
	$ver = $1;
	$dest = $dir."/".$origfile;
	}
else {
	$in{'newver'} =~ /^[0-9\.]+$/ || &error($text{'versions_enewver'});
	$ver = $in{'newver'};
	$dest = $dir."/"."minecraft_server.$in{'newver'}.jar";
	}
my $out = &backquote_command("file ".quotemeta($temp)." 2>&1");
$out =~ /ZIP|JAR/i || &error($text{'versions_efmt'});

# Check for a clash, and write the file
-r $dest && &error($text{'versions_eclash'});
&copy_source_dest($temp, $dest);
&webmin_log("addversion", undef, $ver);
&redirect("list_versions.cgi");
