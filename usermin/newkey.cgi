#!/usr/local/bin/perl
# newkey.cgi
# Create a new SSL key for Usermin

require './usermin-lib.pl';
$access{'ssl'} || &error($text{'acl_ecannot'});
&ReadParse();

# Validate inputs
&error_setup($text{'newkey_err'});
$in{'commonName_def'} || $in{'commonName'} =~ /^[A-Za-z0-9\.\-\*]+$/ ||
	&error($text{'newkey_ecn'});
$in{'newfile'} || &error($text{'newkey_efile'});
$in{'size_def'} || $in{'size'} =~ /^\d+$/ ||
	&error($text{'newkey_esize'});
$in{'days'} =~ /^\d+$/ || &error($text{'newkey_edays'});

&ui_print_header(undef, $text{'newkey_title'}, "");

%aclconfig = &foreign_config('acl');
&foreign_require("acl", "acl-lib.pl");
if (!($cmd = &acl::get_ssleay())) {
	print "<p>",&text('newkey_ecmd',
			"<tt>$aclconfig{'ssleay'}</tt>",
			"@{[&get_webprefix()]}/config.cgi?acl"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

# Create key file
$ctemp = &transname();
$ktemp = &transname();
$outtemp = &transname();
$size = $in{'size_def'} ? $default_key_size : $in{'size'};
&open_execute_command(CA, "$cmd req -newkey rsa:$size -x509 -nodes -out ".quotemeta($ctemp)." -keyout ".quotemeta($ktemp)." -days $in{'days'} >".quotemeta($outtemp)." 2>&1", 0);
print CA ($in{'countryName'} || "."),"\n";
print CA ($in{'stateOrProvinceName'} || "."),"\n";
print CA ($in{'cityName'} || "."),"\n";
print CA ($in{'organizationName'} || "."),"\n";
print CA ($in{'organizationalUnitName'} || "."),"\n";
print CA ($in{'commonName_def'} ? "*" : $in{'commonName'}),"\n";
print CA ($in{'emailAddress'} || "."),"\n";
close(CA);
$rv = $?;
$qouttemp = quotemeta($outtemp);
$out = `cat $qouttemp`;
&unlink_file($outtemp);
if (!-r $ctemp || !-r $ktemp || $?) {
	print "<p>$text{'newkey_essl'}<br>\n";
	print "<pre>$out</pre>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}
&lock_file($in{'newfile'});
&execute_command("cat ".quotemeta($ctemp)." ".quotemeta($ktemp)." 2>&1 >'$in{'newfile'}'", undef, \$catout);
&unlink_file($ctemp);
&unlink_file($ktemp);
if ($catout || $?) {
	print "<p>$text{'newkey_ecat'}<br>\n";
	print "<pre>$catout</pre>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}
&set_ownership_permissions(0, 0, 0600, $in{'newfile'});
&unlock_file($in{'newfile'});

print "<p>$text{'newkey_ok'}<br>\n";
$key = `cat '$in{'newfile'}'`;
print "<pre>$key</pre>";
&ui_print_footer("", $text{'index_return'});

# Configure usermin to use the new file
if ($in{'usenew'}) {
	&lock_file($usermin_miniserv_config);
	&get_usermin_miniserv_config(\%miniserv);
	$miniserv{'keyfile'} = $in{'newfile'};
	delete($miniserv{'certfile'});
	&put_usermin_miniserv_config(\%miniserv);
	&unlock_file($usermin_miniserv_config);
	&restart_usermin_miniserv();
	&webmin_log("newkey", undef, undef, \%in);
	}

