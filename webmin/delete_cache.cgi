#!/usr/local/bin/perl
# Delete selected URLs from the cache

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'cache_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'cache_enone'});

# Remove the files
foreach $d (@d) {
	$d !~ /\.\./ && $d !~ /\0/ || &error($text{'cache_efile'});
	&system_logged("rm -f ".quotemeta("$main::http_cache_directory/$d"));
	}

&webmin_log("deletecache", undef, scalar(@d));
&redirect("cache.cgi?search=".&urlize($in{'search'}));

