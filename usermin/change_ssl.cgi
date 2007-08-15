#!/usr/local/bin/perl
# change_ssl.cgi
# Enable or disable SSL support

require './usermin-lib.pl';
$access{'ssl'} || &error($text{'acl_ecannot'});
&ReadParse();

&lock_file($usermin_miniserv_config);
&get_usermin_miniserv_config(\%miniserv);
$miniserv{'ssl'} = $in{'ssl'};
$key = `cat '$in{'key'}' 2>&1`;
$key =~ /BEGIN RSA PRIVATE KEY/i ||
	&error(&webmin::text('ssl_ekey', $in{'key'}));
$miniserv{'keyfile'} = $in{'key'};
if ($in{'cert_def'}) {
	$key =~ /BEGIN CERTIFICATE/ ||
		&error(&webmin::text('ssl_ecert', $in{'key'}));
	delete($miniserv{'certfile'});
	}
else {
	$cert = `cat '$in{'cert'}' 2>&1`;
	$cert =~ /BEGIN CERTIFICATE/ ||
		&error(&webmin::text('ssl_ecert',$in{'cert'}));
	$miniserv{'certfile'} = $in{'cert'};
	}
$miniserv{'ssl_redirect'} = $in{'ssl_redirect'};
if ($in{'version_def'}) {
	delete($miniserv{'ssl_version'});
	}
else {
	$in{'version'} =~ /^\d+$/ || &error($text{'ssl_eversion'});
	$miniserv{'ssl_version'} = $in{'version'};
	}
foreach $ec (split(/[\r\n]+/, $in{'extracas'})) {
	-r $ec && !-d $ec || &error(&webmin::text('ssl_eextraca', $ec));
	push(@extracas, $ec);
	}
$miniserv{'extracas'} = join("\t", @extracas);
&put_usermin_miniserv_config(\%miniserv);
&unlock_file($usermin_miniserv_config);

&restart_usermin_miniserv();
&webmin_log("ssl", undef, undef, \%in);

&redirect("");

