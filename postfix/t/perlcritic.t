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
        # Skip symlinks: several postfix files (aliases-lib.pl, autoreply.pl,
        # filter.pl, edit_*file.cgi, save_*file.cgi, boxes-lib.pl) are symlinks
        # into the sendmail and mailboxes modules. Those belong to other
        # modules and are linted by their own test suites.
        return if -l;
        return if -d;
        return unless /\.(pl|cgi)\z/;
        # ".pl" is also the Polish translation suffix in Webmin. Skip
        # "<file>.pl" when a sibling "<file>" (no extension) exists, so
        # data files like config.info.pl and module.info.pl are not linted
        # as Perl. (Same heuristic as the repo-root compile.t.)
        if (/^(.*)\.pl\z/ && -e $1) {
            return;
        }
        push(@files, $File::Find::name);
    },
    '.'
);

@files = sort @files;
if (!@files) {
    plan skip_all => 'no perl files to check';
}

my $critic = Perl::Critic->new(
    -profile => "$bindir/../../.perlcriticrc",
);

foreach my $file (@files) {
    my @violations = $critic->critique($file);
    is(scalar @violations, 0, "$file perlcritic");
    if (@violations) {
        diag join("", @violations);
    }
}

done_testing();
