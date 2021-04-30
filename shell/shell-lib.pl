# shell-lib.pl

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

sub get_chroot
{
if (&get_product_name() eq 'webmin') {
	# From Webmin ACL
	return $access{'chroot'} eq '/' ? '' : $access{'chroot'};
	}
else {
	# From Usermin home dir
	my @uinfo = getpwnam($remote_user);
	return $uinfo[7] =~ /^(.*)\/\.\// ? $1 : '';
	}
}

1;

