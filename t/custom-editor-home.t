#!/usr/bin/perl
# A home-relative editor needs a Unix home before either CGI can use a file.
use strict;
use warnings;
no warnings qw(once redefine);
use Test::More;
use FindBin;
use Cwd qw(abs_path);
use File::Temp qw(tempdir);

my $root = abs_path("$FindBin::Bin/..");
open(my $lib, '<', "$root/custom/custom-lib.pl") or die $!;
my $source = do { local $/; <$lib> };
$source =~ /^(sub editor_file\n\{.*?^\})/ms or die 'Missing editor_file';
eval 'no strict; '.$1;
die $@ if $@;
our ($remote_user, %text);
$text{'view_ehome'} = 'A Unix home is required';
sub error { die "$_[0]\n" }
sub error_setup {}
sub ReadParse {}
sub ReadParseMime {}
sub can_run_command { 1 }
sub get_command { { edit => 'notes.txt' } }

my @user = getpwuid($>);
$remote_user = $user[0];
is_deeply([ editor_file({ edit => 'notes.txt' }) ],
	  [ "$user[7]/notes.txt", $> == 0 ? $remote_user : undef ],
	  'relative files use the Unix home and its owner');

$remote_user = "webmin-only-fixture-$$";
die 'fixture name already in use' if getpwnam($remote_user);
is_deeply([ editor_file({ edit => '/srv/team/notes.txt' }) ],
	  [ '/srv/team/notes.txt', undef ], 'absolute files keep the configured path');
my $cwd = tempdir(CLEANUP => 1);
chdir($cwd) or die $!;
local $INC{'./custom-lib.pl'} = 1;
for my $cgi (qw(view.cgi save.cgi)) {
	do "$root/custom/$cgi";
	is($@, "A Unix home is required\n", "$cgi stops before file access");
}
chdir($root) or die $!;
done_testing();
