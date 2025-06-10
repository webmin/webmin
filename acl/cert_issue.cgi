#!/usr/local/bin/perl
# cert_issue.cgi

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './acl-lib.pl';
our (%in, %text, %config, %access, $module_config_directory, $base_remote_user);
&ReadParse();

&error_setup($text{'cert_err'});
$in{'key'} || &error($text{'cert_ekey'});

my %miniserv;
&get_miniserv_config(\%miniserv);

# Create the new key
my $temp1 = &transname();
my $temp2 = &tempname();
my $fh = "IN";
&open_tempfile($fh, ">$temp1");
foreach my $k ("emailAddress", "organizationalUnitName", "organizationName",
	       "stateOrProvinceName", "countryName", "commonName") {
	&print_tempfile($fh, "$k = $in{$k}\n");
	}
$in{'key'} =~ s/\s//g;
&print_tempfile($fh, "SPKAC = $in{'key'}\n");
&close_tempfile($fh);
my $cmd = &get_ssleay();
my $ssleay = &backquote_logged("$cmd ca -spkac $temp1 -out $temp2 -config $module_config_directory/openssl.cnf -days 1095 2>&1");
&unlink_file($temp1);
if ($?) {
	&error("<pre>$ssleay</pre>");
	}
else {
	# Display status and redirect to actual cert file
	&ui_print_unbuffered_header(undef, $text{'cert_title'}, "");
	print &text('cert_done', $in{'commonName'}),"<p>\n";
	print &text('cert_pickup', "cert_output.cgi?file=$temp2"),"<p>\n";
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

