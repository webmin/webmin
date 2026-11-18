#!/usr/bin/perl
# Tests that form input cannot add statements to named.conf or zone files,
# and that valid input such as WKS records and empty ACL directories works.

use strict;
use warnings;
use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Temp qw(tempdir);

my $bindir = abs_path(dirname(__FILE__)."/..");
my $confdir = tempdir(CLEANUP => 1);
my $vardir = tempdir(CLEANUP => 1);
my $zonedir = abs_path(tempdir(CLEANUP => 1));

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

my $named_conf = "$confdir/named.conf";
my $zonefile = "$zonedir/example.com.hosts";
write_text("$confdir/config", "os_type=linux\nos_version=0\n");
write_text("$confdir/var-path", "$vardir\n");
mkdir("$confdir/bind8") || die "bind8: $!";
write_text("$confdir/bind8/config",
	"named_conf=$named_conf\nnamed_path=/bin/true\nshort_names=0\n".
	"soa_style=0\nupdserial_on=1\nallow_wild=1\n");
write_text("$confdir/bind8/version", "9.18.0\n");
write_text($named_conf,
	"options {\n\tdirectory \"$zonedir\";\n};\n".
	"view \"inside\" {\n};\n".
	"zone \"example.com\" {\n\ttype master;\n".
	"\tfile \"$zonefile\";\n};\n");
write_text($zonefile,
	"\$ttl 3600\n".
	"\@\tIN\tSOA\tns1.example.com. root.example.com. ".
	"( 1 3600 600 86400 3600 )\n".
	"\@\tIN\tNS\tns1.example.com.\n");

$ENV{'WEBMIN_CONFIG'} = $confdir;
$ENV{'WEBMIN_VAR'} = $vardir;
$ENV{'FOREIGN_MODULE_NAME'} = 'bind8';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = abs_path("$bindir/..");
$ENV{'REMOTE_USER'} = 'root';

chdir($bindir) || die "chdir: $!";
require './bind8-lib.pl';    ## no critic
our (%access, %in, %config);
{
	no warnings 'once';
	$main::error_must_die = 1;
}

# run_cgi(script, &inputs)
# Runs a CGI with the given inputs, and returns its output and any error
sub run_cgi
{
my ($script, $inputs) = @_;
%in = %$inputs;
my $out = '';
no warnings qw(redefine once);
local *main::ReadParse = sub { };
local *main::webmin_log = sub { };
open(my $fh, '>', \$out) || die $!;
my $old = select($fh);
my $ok = do "./$script";
my $err = $@;
select($old);
close($fh);
&flush_file_lines();
&unlock_all_files();
&clear_config_cache();
return ($out, $err);
}

# --- allowed_zone_file ----------------------------------------------------
ok(&allowed_zone_file({ 'dir' => '' }, "$zonedir/a.hosts"),
   'an empty directory limit allows any zone file');
ok(&allowed_zone_file({ 'dir' => '/' }, "$zonedir/a.hosts"),
   'a / directory limit allows any zone file');
ok(&allowed_zone_file({ 'dir' => $zonedir }, "$zonedir/a.hosts"),
   'a file inside the directory limit is allowed');
ok(!&allowed_zone_file({ 'dir' => $zonedir }, "$zonedir-other/a.hosts"),
   'a sibling directory with the same prefix is denied');
ok(!&allowed_zone_file({ 'dir' => '' }, "$zonedir/../a.hosts"),
   'a path with .. is denied');
ok(!&allowed_zone_file({ 'dir' => '' }, "a.hosts"),
   'a relative path is denied');

# --- save_choice and check_conf_value -------------------------------------
{
	my @saved;
	no warnings qw(redefine once);
	local *main::save_directive = sub { push(@saved, $_[2]) };
	%in = ( 'notify' => 'explicit' );
	&save_choice('notify', { }, 1);
	is($saved[0]->[0]->{'values'}->[0], 'explicit',
	   'an offered choice is saved');
	%in = ( 'notify' => 'yes; }; zone "victim.com" { type master' );
	ok(!eval { &save_choice('notify', { }, 1); 1 },
	   'a choice that closes the zone block is rejected');
	%in = ( 'notify' => 'maybe' );
	ok(!eval { &save_choice('notify', { }, 1); 1 },
	   'a choice that is not offered is rejected');
	is(scalar(@saved), 1, 'rejected choices are not saved');
}
ok(eval { &check_conf_value('10.0.0.0/8', '!192.0.2.1', 'any',
			    '"transfer-key"', '/var/named/a b.hosts'); 1 },
   'addresses, quoted key names and paths are accepted');
foreach my $bad ("1.2.3.4;", "x}", "{", "a\"b", "a\nb", "a\\") {
	(my $label = $bad) =~ s/\n/\\n/g;
	ok(!eval { &check_conf_value($bad); 1 }, "value $label is rejected");
	}

# --- WKS records can be saved ---------------------------------------------
my ($out, $err) = &run_cgi('save_record.cgi', {
	'zone' => 'example.com', 'view' => '', 'type' => 'WKS',
	'new' => 1, 'name' => 'www', 'ttl_def' => 1,
	'value0' => '192.0.2.1', 'value1' => 'tcp',
	'value2' => "smtp\nftp" });
is($err, '', 'a WKS record is saved');
like(&read_text($zonefile), qr/\tWKS\t192\.0\.2\.1 tcp \(\n\t+smtp\n\t+ftp \)/,
     'WKS services are written one per line');
($out, $err) = &run_cgi('save_record.cgi', {
	'zone' => 'example.com', 'view' => '', 'type' => 'WKS',
	'new' => 1, 'name' => 'mail', 'ttl_def' => 1,
	'value0' => '192.0.2.2', 'value1' => "tcp\n\t\tmail IN A 192.0.2.9",
	'value2' => 'smtp' });
isnt($err, '', 'a WKS protocol with a line break is rejected');
unlike(&read_text($zonefile), qr/192\.0\.2\.9/,
       'the rejected WKS record adds nothing');

# --- record generators ----------------------------------------------------
($out, $err) = &run_cgi('save_gen.cgi', {
	'zone' => 'example.com', 'view' => '',
	'type_0' => "PTR\n\@ IN NS evil.example.", 'start_0' => 1,
	'stop_0' => 2, 'skip_0' => '', 'name_0' => '$', 'value_0' => 'h$' });
isnt($err, '', 'a generator type with a line break is rejected');
($out, $err) = &run_cgi('save_gen.cgi', {
	'zone' => 'example.com', 'view' => '', 'type_0' => 'PTR',
	'start_0' => 1, 'stop_0' => 2, 'skip_0' => '', 'name_0' => '$',
	'value_0' => 'h$', 'cmt_0' => "note\n\@ IN NS evil.example." });
isnt($err, '', 'a generator comment with a line break is rejected');
unlike(&read_text($zonefile), qr/evil/, 'rejected generators add nothing');
($out, $err) = &run_cgi('save_gen.cgi', {
	'zone' => 'example.com', 'view' => '', 'type_0' => 'PTR',
	'start_0' => 1, 'stop_0' => 2, 'skip_0' => '', 'name_0' => '$',
	'value_0' => 'h$', 'cmt_0' => 'hosts' });
is($err, '', 'a valid generator is saved');
like(&read_text($zonefile), qr/^\$generate 1-2 \$ PTR h\$ ;hosts$/m,
     'the generator line is written');

done_testing();
