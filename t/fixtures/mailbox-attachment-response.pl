#!/usr/bin/perl
# Render the real attachment CGI with an in-memory mailbox and MIME message.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use File::Basename qw(dirname);
use JSON::PP;

my $root = dirname(__FILE__).'/../..';
require "$root/web-lib-funcs.pl";
require "$root/mailboxes/boxes-lib.pl";
require "$root/mailboxes/folders-lib.pl";
$INC{'./mailboxes-lib.pl'} = 1;

# mailbox_attachment_response(type, data, filename, request, [cgi])
# Decode a MIME attachment and capture its CGI response without mailbox I/O.
sub mailbox_attachment_response
{
my ($type, $data, $filename, $request, $cgi) = @_;
my $message = {
	'header' => { 'content-type' => 'multipart/mixed; boundary=fixture' },
	'body' => "--fixture\nContent-Type: $type\n".
		  "Content-Disposition: attachment; filename=\"$filename\"\n".
		  "Content-Transfer-Encoding: base64\n\n".
		  &main::encode_base64($data)."--fixture--\n",
	};
local *main::ReadParse = sub { };
local *main::can_user = sub { !exists($request->{'deny'}) };
local *main::error = sub { die join(' ', @_)."\n" };
local *main::list_user_folders = sub { return { }; };
local *main::mailbox_list_mails = sub { return $message; };
local *main::pop3_logout_all = sub { };
local %main::in = ( 'user' => 'fixture', 'folder' => 0, 'idx' => 0,
		   'attach' => 0, %$request );
local %main::text = ( 'mail_ecannot' => 'Mailbox access denied' );
local $ENV{'HTTP_HOST'} = 'webmin.example.test';
my $response = '';
open(my $out, '>', \$response) or die "open scalar: $!";
{
	local *STDOUT = $out;
	do ($cgi || "$root/mailboxes/detach.cgi");
	die $@ if ($@);
	}
close($out);
return $response;
}

# A JSON request on stdin lets browser tests serve these exact CGI responses.
if (!caller) {
	local $/;
	my $case = decode_json(<STDIN>);
	print mailbox_attachment_response($case->{'type'},
		&main::decode_base64($case->{'data'}), $case->{'filename'},
		$case->{'request'} || { }, $ARGV[0]);
	}
1;
