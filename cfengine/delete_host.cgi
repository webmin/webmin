#!/usr/local/bin/perl
# delete_host.cgi
# Remove a managed host from the list

require './cfengine-lib.pl';
&ReadParse();
@hosts = &list_cfengine_hosts();
($host) = grep { $_->{'id'} == $in{'id'} } @hosts;
&delete_cfengine_host($host);
&redirect("list_hosts.cgi");

