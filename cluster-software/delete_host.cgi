#!/usr/local/bin/perl
# delete_host.cgi
# Remove a managed host from the list

require './cluster-software-lib.pl';
&ReadParse();
@hosts = &list_software_hosts();
($host) = grep { $_->{'id'} == $in{'id'} } @hosts;
&delete_software_host($host);
&redirect("");

