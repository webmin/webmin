
require 'user-lib.pl';

sub cpan_recommended
{
if (defined(&use_md5)) {
	eval "use MD5";
	local $has_md5 = !$@;
	eval "use Digest::MD5";
	local $has_digest_md5 = !$@;
	if (!$has_md5 && !$has_digest_md5) {
		return ( "Digest::MD5" );
		}
	}
return ( );
}

