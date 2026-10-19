use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
BEGIN {
    eval { require Perl::Critic; 1 }
        or plan skip_all => 'Perl::Critic not installed';
}
# Apply the existing policy to new tests, not untouched legacy module files.
my $critic = Perl::Critic->new(-profile => "$Bin/../../.perlcriticrc");
for my $file (qw(disk-discovery.t fixtures/disk-discovery.pl disk-discovery-perlcritic.t)) {
    my @violations = $critic->critique("$Bin/$file");
    is(scalar @violations, 0, "$file perlcritic");
    diag join('', @violations) if @violations;
}
done_testing();
