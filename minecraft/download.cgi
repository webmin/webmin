#!/usr/local/bin/perl
# Download the latest JAR file during initial setup

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%text, %config, %in);
our $progress_callback_url;
&ReadParse();

# Validate inputs
if ($in{'new'}) {	
	$in{'dir'} =~ /^\/\S+$/ || &error($text{'download_edir'});
	defined(getpwnam($in{'user'})) || &error($text{'download_euser'});
	}

&ui_print_unbuffered_header(undef, $text{'download_title'}, "");

if ($in{'new'}) {
	# Save the config
	$config{'minecraft_dir'} = $in{'dir'};
	$config{'unix_user'} = $in{'user'};
	&save_module_config(\%config);
	}

if ($in{'new'} && !-d $config{'minecraft_dir'}) {
	# Create install dir
	print &text('download_mkdir', $config{'minecraft_dir'}),"<p>\n";
	&make_dir($config{'minecraft_dir'}, 0755) ||
		&error($text{'download_emkdir'});
	&set_ownership_permissions($config{'unix_user'}, undef, 0755,
				   $config{'minecraft_dir'});
	}

# Download to temp file
my $temp = &transname();
$progress_callback_url = &get_server_jar_url();
$progress_callback_url || &error($text{'download_eurl'});
my ($host, $port, $page, $ssl) = &parse_http_url($progress_callback_url);
&http_download($host, $port, $page, $temp, undef, \&progress_callback, $ssl);

# Check if different
my $jar = &get_minecraft_jar();
my $old_md5 = &md5_checksum($jar);
my $new_md5 = &md5_checksum($temp);

if ($old_md5 eq $new_md5) {
	print &text('download_already', $jar),"<p>\n";
	}
else {
	&copy_source_dest($temp, $jar);
	&set_ownership_permissions($config{'unix_user'}, undef, undef, $jar);

	if ($in{'new'}) {
		print &text('download_done2', $jar),"<p>\n";
		}
	else {
		print &text('download_done', $jar),"<p>\n";
		}
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
