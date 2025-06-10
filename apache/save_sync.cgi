#!/usr/local/bin/perl
# save_sync.cgi
# Save user synchronisation options

require './apache-lib.pl';
require './auth-lib.pl';
&ReadParse();
&allowed_auth_file($in{'file'}) || &error(&text('authu_ecannot', $in{'file'}));
$in{'sync'} =~ s/\0/ /g;
if ($in{'sync'}) {
	$config{"sync_$in{'file'}"} = $in{'sync'};
	}
else {
	delete($config{"sync_$in{'file'}"});
	}
&write_file("$module_config_directory/config", \%config);
&redirect("list_authusers.cgi?file=$in{'file'}&url=".&urlize($in{'url'}));

