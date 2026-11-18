#!/usr/bin/perl
# Check which user reads mail folders opened by path.
use strict;
use warnings;
no warnings qw(once redefine);
use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

my $root = abs_path(dirname(__FILE__)."/../..");
my $tmp = abs_path(tempdir(CLEANUP => 1));
require "$root/web-lib-funcs.pl";

# Load the folder functions without the module setup code
open(my $fh, '<', "$root/mailboxes/mailboxes-lib.pl") or die $!;
my $source = do { local $/; <$fh> };
close($fh);
foreach my $name (qw(list_user_folders allowed_directory)) {
	$source =~ /(^sub \Q$name\E\n\{.*?^\}\n)/ms or die "Missing $name";
	eval 'no strict; no warnings; '.$1;
	die $@ if ($@);
	}
our (%access, %text, $remote_user, $allowed_uid);
%text = ( 'view_ecannot' => 'Cannot read' );
*main::error = sub { die join(' ', @_)."\n" };
*main::folder_type = sub { return 0 };
*main::get_mail_uid = sub { return getpwuid($_[0]) };
*main::can_user = sub { return defined($allowed_uid) && $_[2] == $allowed_uid };

# owner(path)
# Returns the user a path folder is read as, or the error
sub owner
{
my ($path) = @_;
my @f = eval { list_user_folders($path) };
return $@ ? $@ : $f[0]->{'user'};
}

# A Virtualmin extra admin has no Unix account, and is limited by group
$remote_user = 'extra-admin-without-unix-account';
%access = ( 'mmode' => 5, 'musers' => 99999, 'dir' => "$tmp/domain" );
make_path("$tmp/domain/mail", "$tmp/outside");
open($fh, '>', "$tmp/domain/mail/inbox") or die $!;
close($fh);
open($fh, '>', "$tmp/outside/secret") or die $!;
close($fh);

is(owner("$tmp/domain/mail/inbox"), $<,
   'file under the allowed directory is read as its owner');
is(owner("$tmp/domain/mail/new"), $<,
   'new file uses the owner of its directory');
is(owner("$tmp/outside/secret"), "Cannot read\n",
   'file outside the allowed directory is refused');
symlink("$tmp/outside/secret", "$tmp/domain/mail/link") or die $!;
is(owner("$tmp/domain/mail/link"), "Cannot read\n",
   'symlink to a file outside the allowed directory is refused');
symlink("$tmp/domain/mail/inbox", "$tmp/domain/mail/inlink") or die $!;
is(owner("$tmp/domain/mail/inlink"), $<,
   'symlink inside the allowed directory is read as its owner');

{
	local $allowed_uid = $<;
	is(owner("$tmp/outside/secret"), $<,
	   'file owned by an allowed user is read as that user');
}

{
	local %access = ( 'mmode' => 1 );
	is(owner("$tmp/outside/secret"), undef,
	   'full access reads as root, as before');
}

done_testing();
