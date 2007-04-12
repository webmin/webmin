#!/usr/local/bin/perl
# delete_host.cgi
# Remove a managed host from the list

require './cluster-webmin-lib.pl';
&ReadParse();
@hosts = &list_webmin_hosts();
($host) = grep { $_->{'id'} == $in{'id'} } @hosts;
&delete_webmin_host($host);
&redirect("");

