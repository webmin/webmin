#!/usr/local/bin/perl
# change_ssl.cgi
# Enable or disable SSL support

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'ssl_err'});

&lock_file($ENV{'MINISERV_CONFIG'});
&get_miniserv_config(\%miniserv);
$miniserv{'ssl'} = $in{'ssl'};
&validate_key_cert($in{'key'}, $in{'cert_def'} ? undef : $in{'cert'});
$miniserv{'keyfile'} = $in{'key'};
$miniserv{'certfile'} = $in{'cert_def'} ? undef : $in{'cert'};
$miniserv{'ssl_redirect'} = $in{'ssl_redirect'};
if ($in{'version_def'}) {
	delete($miniserv{'ssl_version'});
	}
else {
	$in{'version'} =~ /^\d+$/ || &error($text{'ssl_eversion'});
	$miniserv{'ssl_version'} = $in{'version'};
	}
foreach $ec (split(/[\r\n]+/, $in{'extracas'})) {
	-r $ec && !-d $ec || &error(&text('ssl_eextraca', $ec));
	push(@extracas, $ec);
	}
$miniserv{'extracas'} = join("\t", @extracas);
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});

$SIG{'TERM'} = 'IGNORE';	# stop process from being killed by restart
&restart_miniserv();
&webmin_log("ssl", undef, undef, \%in);

$url = "$ENV{'SERVER_NAME'}:$miniserv{'port'}/webmin/";
if ($in{'ssl'}) { &redirect("https://$url"); }
else { &redirect("http://$url"); }

