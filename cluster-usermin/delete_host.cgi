#!/usr/local/bin/perl
# delete_host.cgi
# Remove a managed host from the list

require './cluster-usermin-lib.pl';
&ReadParse();
@hosts = &list_usermin_hosts();
($host) = grep { $_->{'id'} == $in{'id'} } @hosts;
&delete_usermin_host($host);
&redirect("");

