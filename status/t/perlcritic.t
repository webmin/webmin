#!/usr/bin/perl
# Apply the repository profile to the service monitors changed by this fix.
use strict;
use warnings;
use Test::More;
use FindBin;

BEGIN {
	eval { require Perl::Critic; 1 }
		or plan skip_all => 'Perl::Critic not installed';
	}

# These legacy monitors use package globals and eval-based optional modules.
# Keep the remaining severity-5 checks without refactoring unrelated code.
my $critic = Perl::Critic->new(
	-profile => "$FindBin::Bin/../../.perlcriticrc",
	-exclude => [ 'TestingAndDebugging::RequireUseStrict',
		      'BuiltinFunctions::ProhibitStringyEval' ]);
for my $type (qw(ftp smtp imap ldap query)) {
	my @violations = $critic->critique("$FindBin::Bin/../$type-monitor.pl");
	is(scalar(@violations), 0, "$type monitor perlcritic");
	diag join('', @violations) if @violations;
	}
done_testing();
