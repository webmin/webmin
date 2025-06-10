
do 'sendmail-lib.pl';
do 'virtusers-lib.pl';
do 'generics-lib.pl';
do 'domain-lib.pl';
do 'access-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi =~ /^list_/) {
	# All these are OK with no args
	return '';
	}
elsif ($cgi eq 'edit_alias.cgi') {
	# Assume first one
	return 'num=0';
	}
elsif ($cgi eq 'edit_virtuser.cgi') {
	# First virtuser, if any
	my $conf = &get_sendmailcf();
	my $vfile = &virtusers_file($conf);
	my ($vdbm, $vdbmtype) = &virtusers_dbm($conf);
	if ($vdbm) {
		my @virts = &list_virtusers($vfile);
		return @virts ? 'num=0' : 'none';
		}
	return 'none';
	}
elsif ($cgi eq 'edit_generic.cgi') {
	# First outgoing address mapping
	my $conf = &get_sendmailcf();
	my $gfile = &generics_file($conf);
	my ($gdbm, $gdbmtype) = &generics_dbm($conf);
	if ($gdbm) {
		my @gens = &list_generics($gfile);
		return @gens ? 'num=0' : 'none';
		}
	return 'none';
	}
elsif ($cgi eq 'edit_domain.cgi') {
	# First domain table entry
	my $conf = &get_sendmailcf();
	my $dfile = &domains_file($conf);
	my ($ddbm, $ddbmtype) = &domains_dbm($conf);
	if ($ddbm) {
		my @doms = &list_domains($dfile);
		return @doms ? 'num=0' : 'none';
		}
	return 'none';
	}
elsif ($cgi eq 'edit_access.cgi') {
	# First spam control rule
	my $conf = &get_sendmailcf();
	my $afile = &access_file($conf);
	my ($adbm, $adbmtype) = &access_dbm($conf);
	if ($adbm) {
		my @accs = &list_access($afile);
		return @accs ? 'num=0' : 'none';
		}
	return 'none';
	}
return undef;
}
