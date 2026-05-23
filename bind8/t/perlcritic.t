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
        return unless /\.(pl|cgi)\z/;
        # config.info.pl and module.info.pl are Webmin data files,
        # not Perl source (the .pl suffix is overloaded for Polish
        # translations).
        return if $_ eq 'config.info.pl' || $_ eq 'module.info.pl';
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
