#!/usr/local/bin/perl
# Upload or download a new JAR

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%in, %text, %config, $download_page_url);
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
elsif ($in{'mode'} == 1) {
	# Use uploaded file
	$in{'jar'} || &error($text{'versions_ejar'});
	$in{'jar_filename'} || &error($text{'versions_ejar2'});
	my $fh = "JAR";
	&open_tempfile($fh, ">$temp", 0, 1);
	&print_tempfile($fh, $in{'jar'});
	&close_tempfile($fh);
	$origfile = $in{'jar_filename'};
	}
elsif ($in{'mode'} == 2) {
	# Download the latest version
	my ($url, $uver) = &get_server_jar_url();
	$url || &error(&text('versions_elatesturl',
			     &ui_link($download_page_url, $download_page_url,
				      undef, "target=_blank")));
	my ($host, $port, $page, $ssl) = &parse_http_url($url);
	my $err;
	&http_download($host, $port, $page, $temp, \$err, undef, $ssl);
	$err && &error($err);
	$origfile = "minecraft_server.$uver.jar";
	}
else {
	&error("Unknown mode");
	}

# Work out the filename to upload as
my $ver;
my $dir = $config{'minecraft_dir'};
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
&set_ownership_permissions(undef, undef, 0755, $dest);
&webmin_log("addversion", undef, $ver);
&redirect("list_versions.cgi");
