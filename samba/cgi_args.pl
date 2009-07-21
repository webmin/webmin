
do 'samba-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
my @shares = &list_shares();
if ($cgi eq 'edit_pshare.cgi' || $cgi eq 'edit_popts.cgi') {
	# First printer share
	foreach my $s (@shares) {
		next if (!&can('r', \%access, $s) || $s eq 'global');
		local %share;
		&get_share($s);
		if (&istrue("printable")) {
			return 'share='.&urlize($s);
			}
		}
	return $access{'c_ps'} ? '' : 'none';	# Create if allowed
	}
elsif ($cgi eq 'edit_fshare.cgi' || $cgi eq 'edit_sec.cgi' ||
       $cgi eq 'edit_fperm.cgi' || $cgi eq 'edit_fname.cgi' ||
       $cgi eq 'edit_fmisc.cgi') {
	# First non-printer share
	foreach my $s (@shares) {
		next if (!&can('r', \%access, $s) || $s eq 'global');
		local %share;
		&get_share($s);
		if (!&istrue("printable")) {
			return 'share='.&urlize($s);
			}
		}
	return $access{'c_fs'} ? '' : 'none';	# Create if allowed
	}
elsif ($cgi eq 'edit_euser.cgi') {
	# First user, if any
	my @ulist = &list_users();
	return @ulist ? 'idx='.$ulist[0]->{'index'} : 'none';
	}
return undef;
}
