#!/usr/local/bin/perl
# change_access.cgi
# Update IP allow and deny parameters

require './usermin-lib.pl';
$access{'access'} || &error($text{'acl_ecannot'});
use Socket;
&ReadParse();
&error_setup($text{'access_err'});

@hosts = split(/\s+/, $in{"ip"});
&lock_file($usermin_miniserv_config);
&get_usermin_miniserv_config(\%miniserv);
delete($miniserv{"allow"});
delete($miniserv{"deny"});
if ($in{"access"} == 1) { $miniserv{"allow"} = join(' ', @hosts); }
elsif ($in{"access"} == 2) { $miniserv{"deny"} = join(' ', @hosts); }
$miniserv{'libwrap'} = $in{'libwrap'};
$miniserv{'alwaysresolve'} = $in{'alwaysresolve'};
&put_usermin_miniserv_config(\%miniserv);
&unlock_file($usermin_miniserv_config);
&restart_usermin_miniserv();
&webmin_log("access", undef, undef, \%in);
&redirect("");

