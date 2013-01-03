#!/usr/local/bin/perl
# Download the latest JAR file

use strict;
use warnings;
require './minecraft-lib.pl';
our (%text, %config, %in);
our $server_jar_url;
our $progress_callback_url;
&ReadParse();

&ui_print_unbuffered_header(undef, $text{'download_title'}, "");

if ($in{'new'} && -d $config{'minecraft_dir'}) {
	# Create install dir
	print &text('download_mkdir', $config{'minecraft_dir'}),"<p>\n";
	&make_dir($config{'minecraft_dir'}, 0755) ||
		&error($text{'download_emkdir'});
	}

# Download to temp file
my $temp = &transname();
my ($host, $port, $page, $ssl) = &parse_http_url($server_jar_url);
$progress_callback_url = $server_jar_url;
&http_download($host, $port, $page, $temp, undef, \&progress_callback, $ssl);

# Check if different
my $jar = $config{'minecraft_jar'} ||
	  $config{'minecraft_dir'}."/"."minecraft_server.jar";
my $old_md5 = &md5_checksum($jar);
my $new_md5 = &md5_checksum($temp);

if ($old_md5 eq $new_md5) {
	print &text('download_already', $jar),"<p>\n";
	}
else {
	&copy_source_dest($temp, $jar);

	print &text('download_done', $jar),"<p>\n";
	if ($in{'new'}) {
		print $text{'download_start'},"<p>\n";
		print &ui_form_start("start.cgi");
		print &ui_form_end([ [ undef, $text{'index_start'} ] ]);
		}
	elsif (&is_minecraft_server_running()) {
		print $text{'download_restart'},"<p>\n";
		print &ui_form_start("restart.cgi");
		print &ui_form_end([ [ undef, $text{'index_restart'} ] ]);
		}
	}
&unlink_file($temp);

&ui_print_footer("", $text{'index_return'});
