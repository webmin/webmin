
do 'fdisk-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
my @disks = &list_disks_partitions();
if ($cgi eq 'edit_disk.cgi') {
	return @disks ? 'device='.&urlize($disks[0]->{'device'}) : 'none';
	}
elsif ($cgi eq 'edit_part.cgi') {
	return @disks ? 'device='.&urlize($disks[0]->{'device'}).'&part=0'
		      : 'none';
	}
elsif ($cgi eq 'edit_hdparm.cgi') {
	local @hdparm = grep { &supports_hdparm($_) } @disks;
	return @hdparm ? 'disk='.$hdparm[0]->{'index'} : 'none';
	}
return undef;
}
