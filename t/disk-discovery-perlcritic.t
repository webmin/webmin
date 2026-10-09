use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);

BEGIN {
    eval { require Perl::Critic; 1 }
        or plan skip_all => 'Perl::Critic not installed';
}

# These legacy modules have not adopted module-wide Perl::Critic checks.
# Apply the shared policy to the new tests and fixture helper.
my $critic = Perl::Critic->new(-profile => "$Bin/../.perlcriticrc");
for my $file (qw(fdisk/t/disk-discovery.t
                 fdisk/t/fixtures/disk-discovery.pl
                 smart-status/t/disk-discovery.t
                 t/disk-discovery-perlcritic.t)) {
    my @violations = $critic->critique("$Bin/../$file");
    is(scalar @violations, 0, "$file perlcritic");
    diag join('', @violations) if @violations;
}
done_testing();
