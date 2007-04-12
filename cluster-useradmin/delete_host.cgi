#!/usr/local/bin/perl
# delete_host.cgi
# Remove a managed host from the list

require './cluster-useradmin-lib.pl';
&ReadParse();
@hosts = &list_useradmin_hosts();
($host) = grep { $_->{'id'} == $in{'id'} } @hosts;
&delete_useradmin_host($host);
&redirect("");

