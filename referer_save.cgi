#!/usr/local/bin/perl
# redirect_save.cgi
# Redirect to the original URL, and optionally save the redirect flag

require './web-lib.pl';
&init_config();
&ReadParse();

# ONLY relative URLs are allowed
$in{'referer_original'} =~ /^\// || &error($text{'referer_eurl'});

if ($in{'referer_again'}) {
	$gconfig{'referer'} = 1;
	&write_file("$config_directory/config", \%gconfig);
	}
&redirect($in{'referer_original'});

