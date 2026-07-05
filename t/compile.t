#!/usr/local/bin/perl
# Verify every .pl and .cgi in the tree parses (perl -c).
#
# Catches syntax and `use` breakage from bulk refactors without having
# to load every page in a browser. The test is the first line of defence
# for the "we changed thousands of files mechanically, did anything
# break" question.
#
# Skipped:
#   - $file.pl when a sibling $file (no .pl) exists. Webmin uses .pl as
#     the Polish translation suffix, so config.info.pl, module.info.pl,
#     etc. are data files, not Perl.
#   - Files that fail only because of a missing CPAN module. The file
#     itself parses, but `use Foo::Bar` can't resolve at compile time.
#     Treated as a skip so missing optional deps don't gate the suite.
#     Set WEBMIN_COMPILE_T_STRICT=1 to turn these into failures.
#
# Speed: ~12 seconds for the full tree (~3.4k files). Narrow with
# WEBMIN_COMPILE_T_FILTER=<regex> when iterating on one module.

use strict;
use warnings;
use Test::More;
use File::Find;
use File::Basename qw(dirname);
use File::Spec;
use Cwd qw(abs_path getcwd);

my $root = abs_path(File::Spec->catdir(dirname(__FILE__), '..'));
chdir($root) or die "chdir($root): $!";

my $filter = $ENV{WEBMIN_COMPILE_T_FILTER};
my $strict = $ENV{WEBMIN_COMPILE_T_STRICT};

my @files;
find({
	no_chdir => 1,
	wanted => sub {
		return if -d;
		# .pl and .cgi files, plus extensionless files in bin/ with a
		# perl shebang. The shebang check keeps us from compile-checking
		# arbitrary non-perl files just because they share a directory.
		my $name = $File::Find::name;
		my $is_pl_or_cgi = $name =~ /\.(pl|cgi)\z/;
		my $is_bin_dotless = $name =~ m{^\./bin/([^/]+)\z} && $1 !~ /\./;
		return unless $is_pl_or_cgi || $is_bin_dotless;
		# Skip the Polish translations that share the .pl suffix.
		if ($is_pl_or_cgi && $name =~ m{(.+)\.pl\z}) {
			my $base = $1;
			return if -f "$base";
			}
		# For extensionless bin/ scripts, require a perl shebang.
		if ($is_bin_dotless) {
			open(my $fh, '<', $name) or return;
			my $shebang = <$fh>;
			close($fh);
			return unless defined $shebang && $shebang =~ /^#!.*\bperl\b/;
			}
		push(@files, $name);
		},
	}, '.');

@files = sort @files;
@files or BAIL_OUT("found no .pl/.cgi/bin scripts under $root");

if ($filter) {
	@files = grep { /$filter/ } @files;
	@files or do { diag("filter '$filter' matched zero files"); plan skip_all => "no files match filter"; };
	}

if (grep { $_ eq q{./miniserv.pl} } @files) {
	my $cwd = getcwd();
	my $tmpdir = File::Spec->tmpdir();
	my $miniserv = File::Spec->catfile($root, q{miniserv.pl});
	chdir($tmpdir) or BAIL_OUT("chdir($tmpdir): $!");
	my $out = qx{perl -c -- "$miniserv" 2>&1};
	chdir($cwd) or BAIL_OUT("chdir($cwd): $!");
	if ($out =~ /\bsyntax OK\b/) {
		pass(q{miniserv.pl compiles outside the source tree});
		}
	else {
		fail(q{miniserv.pl compiles outside the source tree});
		diag($out);
		}
	}

diag("compile-checking " . scalar(@files) . " files");

for my $f (@files) {
	my $rel = $f;
	$rel =~ s{^\./}{};
	my $out = qx{perl -I. -c -- "$rel" 2>&1};
	if ($out =~ /\bsyntax OK\b/) {
		pass("$rel compiles");
		}
	elsif (!$strict && $out =~ /Can't locate (\S+\.pm) in \@INC/) {
		SKIP: { skip("$rel: missing optional CPAN module $1", 1); }
		}
	else {
		fail("$rel compiles");
		diag($out);
		}
	}

done_testing();

