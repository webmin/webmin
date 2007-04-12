#!/usr/local/bin/perl
# Delete all URLs from the cache

require './webmin-lib.pl';

&system_logged("rm -f ".quotemeta($main::http_cache_directory)."/*");
&webmin_log("clearcache");
&redirect("edit_proxy.cgi");

