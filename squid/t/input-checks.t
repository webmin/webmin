#!/usr/bin/perl
# Tests that access and authentication settings stay on one line.

use strict;
use warnings;
use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

my $moddir = abs_path(dirname(__FILE__)."/..");
my $tmp = abs_path(tempdir(CLEANUP => 1));
my $confdir = "$tmp/webmin-config";
my $vardir = "$tmp/webmin-var";
my $squiddir = "$tmp/etc/squid";
my $otherdir = "$tmp/etc/other";
make_path("$confdir/squid", $vardir, $squiddir, $otherdir);

# write_text(file, text)
# Writes a fixture file or dies
sub write_text
{
my ($file, $text) = @_;
open(my $fh, ">", $file) || die "$file: $!";
print $fh $text;
close($fh) || die "$file: $!";
}

# read_text(file)
# Returns the contents of a fixture file
sub read_text
{
my ($file) = @_;
open(my $fh, "<", $file) || die "$file: $!";
local $/;
my $text = <$fh>;
close($fh);
return $text;
}

my $squid_conf = "$squiddir/squid.conf";
write_text("$confdir/config", "os_type=linux\nos_version=0\n");
write_text("$confdir/miniserv.conf", "root=".abs_path("$moddir/..")."\n");
write_text("$confdir/squid/config",
	"squid_conf=$squid_conf\ncrypt_conf=0\n");
write_text("$confdir/squid/version", "4.0\n");
write_text($squid_conf, "http_port 3128\n");

$ENV{'WEBMIN_CONFIG'} = $confdir;
$ENV{'WEBMIN_VAR'} = $vardir;
$ENV{'FOREIGN_MODULE_NAME'} = 'squid';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = abs_path("$moddir/..");
$ENV{'REMOTE_USER'} = 'root';

chdir($moddir) || die "chdir: $!";
require './squid-lib.pl';    ## no critic
our (%access, %in, $auth_database);
{
	no warnings 'once';
	$main::error_must_die = 1;
}

# run_cgi(script, &inputs)
# Runs a CGI with the given inputs, and returns any error
sub run_cgi
{
my ($script, $inputs) = @_;
%in = %$inputs;
my $out = '';
no warnings qw(redefine once);
local *main::ReadParse = sub { };
local *main::ReadParseMime = sub { };
local *main::webmin_log = sub { };
open(my $fh, '>', \$out) || die $!;
my $old = select($fh);
do "./$script";
my $err = $@;
select($old);
close($fh);
&unlock_all_files();
@main::get_config_cache = ( );
%main::file_cache = ( );
return $err;
}

# --- line breaks in squid.conf values -------------------------------------
write_text($squid_conf, "http_port 3128\n");
@main::get_config_cache = ( );
my $err = &run_cgi('acl_save.cgi', { 'name' => 'browsers', 'type' => 'browser',
				  'file_def' => 1,
				  'vals' => "Mozilla\nhttp_access allow all" });
isnt($err, '', 'an ACL value with a line break is rejected');
$err = &run_cgi('acl_save.cgi', { 'name' => 'browsers', 'type' => 'browser',
				  'file_def' => 1, 'vals' => 'Mozilla',
				  'deny' => "http://x/\nhttp_access allow all" });
isnt($err, '', 'a deny page with a line break is rejected');
unlike(&read_text($squid_conf), qr/allow all/, 'squid.conf is unchanged');
$err = &run_cgi('acl_save.cgi', { 'name' => 'browsers', 'type' => 'browser',
				  'file_def' => 1, 'vals' => 'Mozilla' });
is($err, '', 'a browser ACL is saved');
like(&read_text($squid_conf), qr/^acl browsers browser Mozilla$/m,
     'the ACL line is written');
$err = &run_cgi('save_authparam.cgi', {
	'b_auth_mode' => 0, 'd_auth_mode' => 0, 'n_auth_mode' => 0,
	'b_children_def' => 1, 'b_ttl_def' => 1, 'b_aittl_def' => 1,
	'd_children_def' => 1, 'd_realm_def' => 1, 'n_children_def' => 1,
	'n_reuses_def' => 1, 'n_ttl_def' => 1,
	'b_realm' => "Proxy\nhttp_access allow all" });
isnt($err, '', 'an authentication realm with a line break is rejected');
unlike(&read_text($squid_conf), qr/allow all/, 'squid.conf is still unchanged');

done_testing();
