#!/usr/local/bin/perl
# cert_issue.cgi

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './acl-lib.pl';    ## no critic
our (%in, %text, %config, %access, $module_config_directory, $base_remote_user);
$access{'cert'} || &error($text{'cert_ecannot'});
&ReadParse();

&error_setup($text{'cert_err'});
$in{'key'} || &error($text{'cert_ekey'});

my %miniserv;
&get_miniserv_config(\%miniserv);

uc($ENV{'HTTPS'}) eq "ON" && $miniserv{'ca'} || &error($text{'cert_ecannot'});
$in{'commonName'} = $base_remote_user;

# Create the new key
my $temp1 = &transname();
my $temp2 = &transname();
my $fh = "IN";
&open_tempfile($fh, ">$temp1");
foreach my $k ("emailAddress", "organizationalUnitName", "organizationName",
	       "stateOrProvinceName", "countryName", "commonName") {
	# Colons split the users file, and line breaks would add SPKAC fields.
	$in{$k} =~ s/^\s+|\s+$//g;
	$in{$k} =~ /[:\r\n\0]/ && &error($text{'cert_echars'});

	# OpenSSL parses this file as config, so escape its special characters
	# to keep the signed DN identical to the DN stored for this account.
	# Slashes are safe because logins match the whole DN string, which
	# always ends with this account's forced common name.
	(my $value = $in{$k}) =~ s/([\\'"#\$])/\\$1/g;
	&print_tempfile($fh, "$k = $value\n");
	}
$in{'key'} =~ s/\s//g;
&print_tempfile($fh, "SPKAC = $in{'key'}\n");
&close_tempfile($fh);
my $cmd = &get_ssleay();
my $ssleay = &backquote_logged("$cmd ca -spkac $temp1 -out $temp2 -config $module_config_directory/openssl.cnf -days 1095 2>&1");
my $status = $?;
&unlink_file($temp1);
if ($status) {
	&error("<pre>".&html_escape($ssleay)."</pre>");
	}
else {
	# Publish the signed certificate only for the account that requested it.
	my $pending = &pending_certificate_file();
	&copy_source_dest($temp2, $pending) || &error($text{'cert_etempdir'});
	&unlink_file($temp2);
	&ui_print_unbuffered_header(undef, $text{'cert_title'}, "");
	print &text('cert_done', &html_escape($in{'commonName'})),"<p>\n";
	print &text('cert_pickup', "cert_output.cgi"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});

	# Update the Webmin user
	my ($me) = grep { $_->{'name'} eq $base_remote_user } &list_users();
	$me || &error($text{'edit_egone'});
	$me->{'cert'} = "/C=$in{'countryName'}".
			"/ST=$in{'stateOrProvinceName'}".
			"/O=$in{'organizationName'}".
			"/OU=$in{'organizationalUnitName'}".
			"/CN=$in{'commonName'}".
			"/Email=$in{'emailAddress'}";
	&modify_user($me->{'name'}, $me);

	sleep(1);
	&restart_miniserv();
	&webmin_log("cert", undef, $base_remote_user, \%in);
	}

