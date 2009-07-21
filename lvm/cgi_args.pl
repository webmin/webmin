
do 'lvm-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
my @vgs = &list_volume_groups();
if ($cgi eq 'edit_vg.cgi') {
	# First volume group
	return @vgs ? 'vg='.&urlize($vgs[0]->{'name'}) : 'new=1';
	}
elsif ($cgi eq 'edit_pv.cgi') {
	# First physical volume in group
	if (@vgs) {
		local @pvs = &list_physical_volumes($vgs[0]->{'name'});
		return 'vg='.&urlize($vgs[0]->{'name'}).'&'.
		       (@pvs ? 'pv='.$pvs[0]->{'name'} : 'new=1');
		}
	else {
		return 'none';
		}
	}
elsif ($cgi eq 'edit_lv.cgi') {
	# First logical volume in group
	if (@vgs) {
		local @lvs = &list_logical_volumes($vgs[0]->{'name'});
		return 'vg='.&urlize($vgs[0]->{'name'}).'&'.
		       (@lvs ? 'lv='.$lvs[0]->{'name'} : 'new=1');
		}
	else {
		return 'none';
		}
	}
return undef;
}
