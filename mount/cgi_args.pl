
do 'mount-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'edit_mount.cgi') {
	# Find root filesystem, or first mount
	my @mounts = &list_mounts();
	return 'none' if (!@mounts);
	my $i = 0;
	foreach my $m (@mounts) {
		if ($m->[0] eq '/') {
			return 'index='.$i;
			}
		$i++;
		}
	return 'index=0';
	}
return undef;
}
