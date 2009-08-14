#!/usr/local/bin/perl
# Change OSDN download settings

require './webmin-lib.pl';
&error_setup($text{'proxy_err'});
&ReadParse();

if ($in{'clear'}) {
	# Just clearing Webmin's cache
	&ui_print_header(undef, $text{'clear_title'}, "");

	$sz = &disk_usage_kb($main::http_cache_directory)*1024;
	if ($sz > 0) {
		opendir(DIR, $main::http_cache_directory);
		@files = readdir(DIR);
		closedir(DIR);
		&system_logged("rm -rf ".
			       quotemeta($main::http_cache_directory));
		print &text('clear_done', &nice_size($sz), @files-2),"<p>\n";
		&webmin_log("osdnclear");
		}
	else {
		print &text('clear_none'),"<p>\n";
		}
	
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

&lock_file("$config_directory/config");

# Save cache size
if ($in{'cache_def'}) {
	delete($gconfig{'cache_size'});
	}
else {
	$in{'cache'} =~ /^\d+$/ || &error($text{'proxy_ecache'});
	$gconfig{'cache_size'} = $in{'cache_units'}*$in{'cache'};
	}

# Save cache days
if ($in{'days_def'}) {
	delete($gconfig{'cache_days'});
	}
else {
	$in{'days'} =~ /^\d+$/ || &error($text{'proxy_edays'});
	$gconfig{'cache_days'} = $in{'days'};
	}

# Save modules
if ($in{'mods_def'} == 0) {
	delete($gconfig{'cache_mods'});
	}
else {
	@mods = split(/\0/, $in{'mods'});
	@mods || &error($text{'proxy_emods'});
	if ($in{'mods_def'} == 1) {
		$gconfig{'cache_mods'} = join(" ", @mods);
		}
	else {
		$gconfig{'cache_mods'} = "!".join(" ", @mods);
		}
	}

# Write out the file
&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");
&webmin_log('osdn', undef, undef, \%in);

&redirect("");

