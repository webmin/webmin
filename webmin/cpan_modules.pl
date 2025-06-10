
require 'webmin-lib.pl';

sub cpan_recommended
{
local @rv = ( "Sys::Syslog" );
if (&has_command("openssl")) {
	push(@rv, "Net::SSLeay");
	}
eval "crypt('foo', 'xx')";
if ($@) {
	push(@rv, "Crypt::UnixCrypt");
	}
return @rv;
}

