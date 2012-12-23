#!/usr/local/bin/perl
# Copy Webmin's SSL settings

require './usermin-lib.pl';
&ReadParse();
&error_setup($text{'copycert_err'});

&get_miniserv_config(\%wminiserv);
$wminiserv{'ssl'} || &error($text{'copycert_essl'});
$wminiserv{'keyfile'} || &error($text{'copycert_ekeyfile'});

&lock_file($usermin_miniserv_config);
&get_usermin_miniserv_config(\%miniserv);

# Copy across the key file
$miniserv{'keyfile'} ||= $config{'usermin_dir'}."/miniserv.pem";
if ($miniserv{'keyfile'} ne $wminiserv{'keyfile'}) {
	&lock_file($miniserv{'keyfile'});
	&copy_source_dest($wminiserv{'keyfile'},
			  $miniserv{'keyfile'});
	&unlock_file($miniserv{'keyfile'});
	}
if ($wminiserv{'certfile'}) {
	$miniserv{'certfile'} ||= $config{'usermin_dir'}."/miniserv.cert";
	if ($miniserv{'certfile'} ne $wminiserv{'certfile'}) {
		&lock_file($miniserv{'certfile'});
		&copy_source_dest($wminiserv{'certfile'},
				  $miniserv{'certfile'});
		&unlock_file($miniserv{'certfile'});
		}
	}
else {
	delete($miniserv{'certfile'});
	}

# Copy other settings
$miniserv{'ssl'} = $wminiserv{'ssl'};
$miniserv{'ssl_redirect'} = $wminiserv{'ssl_redirect'};
$miniserv{'ssl_version'} = $wminiserv{'ssl_version'};
$miniserv{'ssl_cipher_list'} = $wminiserv{'ssl_cipher_list'};
$miniserv{'extracas'} = $wminiserv{'extracas'};

# Copy per-IP certs
@ipkeys = &webmin::get_ipkeys(\%wminiserv);
&webmin::save_ipkeys(\%miniserv, \@ipkeys);

&put_usermin_miniserv_config(\%miniserv);
&unlock_file($usermin_miniserv_config);

$SIG{'TERM'} = 'IGNORE';	# stop process from being killed by restart
&restart_usermin_miniserv();
&webmin_log("copycert");

&redirect("");
