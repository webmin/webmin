#!/usr/local/bin/perl
# change_ssl.cgi
# Enable or disable SSL support

require './usermin-lib.pl';
&ReadParse();
&error_setup($text{'ssl_err'});

&lock_file($usermin_miniserv_config);
&get_usermin_miniserv_config(\%miniserv);
$miniserv{'ssl'} = $in{'ssl'};
&webmin::validate_key_cert($in{'key'}, $in{'cert_def'} ? undef : $in{'cert'});
$miniserv{'keyfile'} = $in{'key'};
$miniserv{'certfile'} = $in{'cert_def'} ? undef : $in{'cert'};
$miniserv{'ssl_redirect'} = $in{'ssl_redirect'};
$miniserv{'no_sslcompression'} = !$in{'ssl_compression'};
$miniserv{'ssl_honorcipherorder'} = $in{'ssl_honorcipherorder'};
if ($in{'version_def'}) {
	delete($miniserv{'ssl_version'});
	}
else {
	$in{'version'} =~ /^\d+$/ || &error($text{'ssl_eversion'});
	$miniserv{'ssl_version'} = $in{'version'};
	}
$miniserv{'no_ssl2'} = $in{'no_ssl2'};
$miniserv{'no_ssl3'} = $in{'no_ssl3'};
if ($in{'cipher_list_def'} == 1) {
	delete($miniserv{'ssl_cipher_list'});
	}
elsif ($in{'cipher_list_def'} == 2) {
	$miniserv{'ssl_cipher_list'} = $webmin::strong_ssl_ciphers;
	}
elsif ($in{'cipher_list_def'} == 3) {
	$miniserv{'ssl_cipher_list'} = $webmin::pfs_ssl_ciphers;
	}
else {
	$in{'cipher_list'} =~ /^\S+$/ || &error($text{'ssl_ecipher_list'});
	$miniserv{'ssl_cipher_list'} = $in{'cipher_list'};
	}
foreach $ec (split(/[\r\n]+/, $in{'extracas'})) {
	-r $ec && !-d $ec || &error(&text('ssl_eextraca', $ec));
	push(@extracas, $ec);
	}
$miniserv{'extracas'} = join("\t", @extracas);
&put_usermin_miniserv_config(\%miniserv);
&unlock_file($usermin_miniserv_config);

$SIG{'TERM'} = 'IGNORE';	# stop process from being killed by restart
&restart_usermin_miniserv();
&webmin_log("ssl", undef, undef, \%in);

&redirect("");
