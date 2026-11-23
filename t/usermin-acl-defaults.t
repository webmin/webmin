#!/usr/bin/perl
# Check that Usermin Configuration ACLs saved before the descs, logout,
# mobile, twofactor and web icon keys existed still grant those pages, while
# explicit denials are kept.
use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use Cwd qw(abs_path);
use File::Temp qw(tempdir);

my $root = abs_path("$Bin/..");
my $confdir = tempdir(CLEANUP => 1);
my $vardir = tempdir(CLEANUP => 1);
mkdir("$confdir/usermin") or die $!;

# write_text(file, text) creates a fixture file.
sub write_text
{
my ($file, $text) = @_;
open(my $fh, '>', $file) or die "$file: $!";
print $fh $text;
close($fh) or die "$file: $!";
}

write_text("$confdir/config", "os_type=generic-linux\nos_version=0\n");
write_text("$confdir/var-path", "$vardir\n");
# An ACL saved by an older version, limited only in the bind icon
write_text("$confdir/usermin/old.acl", "access=1\nbind=0\nmods=*\n");
# An ACL saved by this version, with two of the new icons denied
write_text("$confdir/usermin/limited.acl",
	   "access=1\ndescs=0\nlogout=1\nmobile=1\ntwofactor=1\nweb=\n");

$ENV{'WEBMIN_CONFIG'} = $confdir;
$ENV{'WEBMIN_VAR'} = $vardir;
$ENV{'FOREIGN_MODULE_NAME'} = 'usermin';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $root;
chdir("$root/usermin") or die $!;
push(@INC, $root);
require "$root/web-lib.pl";
&main::init_config();

my @new = qw(descs logout mobile twofactor web);
my %old = &main::get_module_acl('old', 'usermin');
ok($old{$_}, "missing $_ key uses the default grant") foreach (@new);
ok(!$old{'bind'}, 'older explicit denial is kept');

my %none = &main::get_module_acl('nofile', 'usermin');
ok($none{$_}, "admin without a saved ACL can use $_") foreach (@new);

my %limited = &main::get_module_acl('limited', 'usermin');
ok(!$limited{'descs'}, 'explicit descs denial is kept');
ok(!$limited{'web'}, 'explicit empty web value is kept');
ok($limited{'mobile'}, 'explicit grant is kept');

done_testing();
