#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

BEGIN {
    eval { require Perl::Critic; 1 }
        or plan skip_all => 'Perl::Critic not installed';
}

use File::Find;

sub script_dir
{
    my $path = $0;
    if ($path =~ m{^/}) {
        $path =~ s{/[^/]+$}{};
        return $path;
    }
    my $cwd = `pwd`;
    chomp($cwd);
    if ($path =~ m{/}) {
        $path =~ s{/[^/]+$}{};
        return $cwd.'/'.$path;
    }
    return $cwd;
}

my $bindir = script_dir();
my $module_dir = "$bindir/..";
chdir($module_dir) or die "chdir: $!";

my @files;
find(
    sub {
        return if -d;
        # Skip symlinks: shared libs (e.g. md5-lib.pl -> ../useradmin/md5-lib.pl)
        # belong to the module that owns the underlying file.
        return if -l;
        return unless /\.(pl|cgi)\z/;
        # *.info.pl is the Polish-locale translation of *.info, not Perl code.
        return if /\.info\.pl\z/;
        push(@files, $File::Find::name);
    },
    '.'
);

@files = sort @files;
if (!@files) {
    plan skip_all => 'no perl files to check';
}

my $critic = Perl::Critic->new(
    -severity => 5,
    -profile => '',
);

foreach my $file (@files) {
    my @violations = $critic->critique($file);
    is(scalar @violations, 0, "$file perlcritic");
    if (@violations) {
        diag join("", @violations);
    }
}

done_testing();
