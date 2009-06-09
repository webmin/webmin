
do 'software-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'search.cgi') {
	# Example search
	return 'search=ssh';
	}
elsif ($cgi eq 'edit_pack.cgi' || $cgi eq 'list_pack.cgi') {
	# Package for /bin/ls
	local %file;
	&installed_file('/bin/ls');
	my @pkgs = split(/\s+/, $file{'packages'});
	my @vers = split(/\s+/, $file{'versions'});
	return 'package='.&urlize($pkgs[0]).
	       '&version='.&urlize($vers[0]);
	}
elsif ($cgi eq 'file_info.cgi') {
	# Info on file /bin/ls
	return 'file=/bin/ls';
	}
return undef;
}
