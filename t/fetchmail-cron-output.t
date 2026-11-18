#!/usr/bin/perl
# Check where the root Fetchmail cron job may write its output.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use FindBin;

my $root = "$FindBin::Bin/..";
require "$root/web-lib-funcs.pl";
require "$FindBin::Bin/test-lib.pl";

# Load the ACL helpers without the module setup code
my $source = read_text("$root/fetchmail/fetchmail-lib.pl");
foreach my $name (qw(can_edit_user output_file_user)) {
	$source =~ /(^sub \Q$name\E\n\{.*?^\}\n)/ms or die "Missing $name";
	eval 'no strict; no warnings; '.$1;
	die $@ if ($@);
	}

# Replace setup, logging and the cron module with a recorder
$INC{'./fetchmail-lib.pl'} = 1;
*main::ReadParse = sub { };
*main::error = sub { die join(' ', @_)."\n" };
*main::foreign_require = sub { };
*main::lock_file = *main::unlock_all_files = sub { };
*main::webmin_log = *main::redirect = sub { };
our $saved;
*cron::list_cron_jobs = sub { return ( ) };
*cron::parse_times_input = *cron::create_wrapper = sub { };
*cron::cron_file = sub { return "/fixture/crontab" };
*cron::create_cron_job = sub { $saved = $_[0]->{'command'} };
open(my $lang, '<', "$root/fetchmail/lang/en") or die $!;
while (<$lang>) {
	$main::text{$1} = $2 if /^(\S+)=(.*)$/;
	}
close($lang);
$main::can_cron = 1;
$main::cron_user = 'root';
$main::cron_cmd = '/fixture/fetchmail/check.pl';

# save_cron(file, &access)
# Runs save_cron.cgi for file output, and returns the job command and error
sub save_cron
{
my ($file, $acl) = @_;
local %main::in = ( 'enabled' => 1, 'output' => 1, 'file' => $file );
local %main::access = %$acl;
local $saved;
eval { do "$root/fetchmail/save_cron.cgi"; die $@ if ($@); };
return ($saved, $@);
}

my @me = getpwuid($<);
$main::remote_user = $me[0];
my $home = "$me[7]/fetchmail.log";

my ($cmd, $err) = save_cron('/var/log/fetchmail.log', { 'mode' => 0 });
is($err, '', 'unrestricted user can write anywhere');
my $qfile = quotemeta('/var/log/fetchmail.log');
like($cmd, qr/--file \Q$qfile\E$/, 'file is set');
unlike($cmd, qr/--file-user/, 'output is written as root');

($cmd, $err) = save_cron($home, { 'mode' => 3 });
is($err, '', 'restricted user can write under his home directory');
my $quser = quotemeta($me[0]);
like($cmd, qr/--file-user \Q$quser\E$/, 'output is written as that user');

($cmd, $err) = save_cron('/etc/cron.d/fetchmail', { 'mode' => 3 });
is($err, $main::text{'cron_efilehome'}."\n",
   'restricted user cannot write outside allowed home directories');
is($cmd, undef, 'no job created');

($cmd, $err) = save_cron("$home\n* * * * * root id", { 'mode' => 0 });
is($err, $main::text{'cron_efile'}."\n", 'line break in the file refused');

done_testing();
