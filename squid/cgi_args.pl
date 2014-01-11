
use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
do 'squid-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
my $conf = &get_config();
if ($cgi eq 'edit_cache_host.cgi') {
	# First other cache
	my $cache_host = $squid_version >= 2 ? "cache_peer" : "cache_host";
	my @ch = &find_config($cache_host, $conf);
	return @ch ? 'num=0' : 'new=1';
	}
elsif ($cgi eq 'always.cgi' && $squid_version >= 2.3) {
	# First ACL to always fetch directly
	my @always = &find_config("always_direct", $conf);
	return @always ? 'index='.$always[0]->{'index'} : 'new=1';
	}
elsif ($cgi eq 'never.cgi' && $squid_version >= 2.3) {
	# First ACL to never fetch directly
	my @never = &find_config("never_direct", $conf);
	return @never ? 'index='.$never[0]->{'index'} : 'new=1';
	}
elsif ($cgi eq 'acl.cgi') {
	# First ACL rule
	my @acls = &find_config("acl", $conf);
	return @acls ? 'index='.$acls[0]->{'index'} : 'type=src';
	}
elsif ($cgi eq 'http_access.cgi') {
	# First HTTP rule
	my @https = &find_config("http_access", $conf);
	return @https ? 'index='.$https[0]->{'index'} : 'new=1';
	}
elsif ($cgi eq 'icp_access.cgi') {
	# First ICP rule
	my @icps = &find_config("icp_access", $conf);
	return @icps ? 'index='.$icps[0]->{'index'} : 'new=1';
	}
elsif ($cgi eq 'edit_ext.cgi' && $squid_version >= 2.5) {
	# First external authenticator
	my @exts = &find_config("external_acl_type", $conf);
	return @exts ? 'index='.$exts[0]->{'index'} : 'new=1';
	}
elsif ($cgi eq 'http_reply_access.cgi' && $squid_version >= 2.5) {
	# First reply rule
	my @replies = &find_config("http_reply_access", $conf);
	return @replies ? 'index='.$replies[0]->{'index'} : 'new=1';
	}
elsif ($cgi eq 'edit_acl.cgi') {
	# Supports linking, even though it calls ReadParse
	return '';
	}
elsif ($cgi eq 'edit_pool.cgi') {
	# First delay pool
	my @pools = &find_config("delay_class", $conf);
	return @pools ? 'idx='.$pools[0]->{'values'}->[0] : 'new=1';
	}
elsif ($cgi eq 'edit_headeracc.cgi') {
	# Creating request header
	return 'new=1&type=request_header_access';
	}
elsif ($cgi eq 'edit_refresh.cgi') {
	# First refresh rule
	my @refresh = &find_config("refresh_pattern", $conf);
	return @refresh ? 'index='.$refresh[0]->{'index'} : 'new=1';
	}
return undef;
}
