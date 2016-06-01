use strict;
use warnings;
our (%config);

do 'bind8-lib.pl';

sub feedback_files
{
my @rv = ( &make_chroot($config{'named_conf'}) );
my $conf = &get_config();
my @views = &find("view", $conf);
my @zones;
foreach my $v (@views) {
	push(@zones, &find("zone", $v->{'members'}));
	}
push(@zones, &find("zone", $conf));
foreach my $z (@zones) {
	my $tv = &find("type", $z->{'members'});
	if ($tv->{'value'} eq 'primary') {
		my $fv = &find("file", $z->{'members'});
		if ($fv) {
			push(@rv, $fv->{'value'});
			}
		}
	}
return @rv;
}

1;

