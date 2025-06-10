#!/usr/local/bin/perl
# change_proxy.cgi
# Change proxy settings

require './webmin-lib.pl';
&error_setup($text{'proxy_err'});
&ReadParse();

&lock_file("$config_directory/config");
if ($in{'http_def'}) { delete($gconfig{'http_proxy'}); }
elsif ($in{'http'} !~ /^http:\/\/(\S+):(\d+)/) {
	&error(&text('proxy_ehttp2', "http://proxy.foo.com:8080/"));
	}
else { $gconfig{'http_proxy'} = $in{'http'}; }

if ($in{'ftp_def'}) { delete($gconfig{'ftp_proxy'}); }
elsif ($in{'ftp'} !~ /^http:\/\/(\S+):(\d+)/) {
	&error(&text('proxy_eftp2', "http://proxy.foo.com:8080/"));
	}
else { $gconfig{'ftp_proxy'} = $in{'ftp'}; }

if ($in{'bind_def'}) {
	delete($gconfig{'bind_proxy'});
	}
else {
	&check_ipaddress($in{'bind'}) || &error($text{'proxy_ebind'});
	$gconfig{'bind_proxy'} = $in{'bind'};
	}
$gconfig{'proxy_fallback'} = $in{'fallback'};

$gconfig{'proxy_user'} = $in{'puser'};
$gconfig{'proxy_pass'} = $in{'ppass'};
$gconfig{'noproxy'} = $in{'noproxy'};

# Write out the config
&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");
&webmin_log('proxy', undef, undef, \%in);

&redirect("");

