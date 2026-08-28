#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

BEGIN {
eval { require Perl::Critic; 1 }
	or plan skip_all => 'Perl::Critic not installed';
}

use File::Find;

# script_dir()
# Returns the directory containing this test file.
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
my $profile = "$bindir/../../.perlcriticrc";
if (!-r $profile) {
plan skip_all => 'Perl::Critic profile not installed';
}
chdir($module_dir) or die "chdir: $!";

my @files;
find(
	sub {
	return if -d;
	return if -l;
	return unless /\.(pl|cgi)\z/;
	return if /\.info\.pl\z/;
	push(@files, $File::Find::name);
	},
	'.'
);
@files = sort @files;
plan skip_all => 'no Perl files to check' if (!@files);

my $critic = Perl::Critic->new(-profile => $profile);
foreach my $file (@files) {
	my @violations = $critic->critique($file);
	is(scalar(@violations), 0, "$file perlcritic");
	diag join("", @violations) if (@violations);
	}

done_testing();
