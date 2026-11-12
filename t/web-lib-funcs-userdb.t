#!/usr/bin/perl
# Check transaction completion separately from cached connection lifetime.
use strict;
use warnings;
no warnings qw(once redefine);
use Test::More;
use FindBin;
require "$FindBin::Bin/../web-lib-funcs.pl";

{
	package UserdbFixture;
	# commit(): publish pending changes, or simulate a deferred SQL failure.
	sub commit {
		my ($self) = @_;
		$self->{'commits'}++;
		return 0 if ($self->{'fail'});
		$self->{'visible'} = delete($self->{'pending'});
		return 1;
	}
	# disconnect(): record closing the underlying connection.
	sub disconnect { $_[0]->{'closed'}++; }
	# unbind(): record an LDAP logout, which has no SQL transaction.
	sub unbind { $_[0]->{'unbound'}++; }
	# errstr(): return the simulated commit error.
	sub errstr { return 'deferred constraint failed'; }
}

local *main::get_miniserv_config = sub { %{$_[0]} = ( ); };
local *main::error = sub { die "$_[0]\n"; };

# Both SQL backends must publish writes without losing connection reuse.
for my $proto ('postgresql', 'mysql') {
	my $str = "$proto://fixture:unused\@localhost/test";
	my $dbh = bless { AutoCommit => 0, pending => 'first' }, 'UserdbFixture';
	local %main::connect_userdb_cache = ( $str => [ $dbh ] );
	local %main::connect_userdb_cache_time = ( $str => time() );
	main::disconnect_userdb($str, $dbh);
	is($dbh->{'visible'}, 'first', "$proto cached release commits writes");
	ok(!$dbh->{'closed'}, "$proto connection stays open");
	is(main::connect_userdb($str), $dbh, "$proto reuses the same handle");
	$dbh->{'pending'} = 'second';
	main::disconnect_userdb($str, $dbh, 1);
	is($dbh->{'visible'}, 'second', "$proto forced close commits writes");
	is($dbh->{'closed'}, 1, "$proto forced close disconnects");
	ok(!exists($main::connect_userdb_cache{$str}), "$proto cache cleared");
}

# AutoCommit and LDAP handles must not receive manual SQL commits.
for my $proto ('postgresql', 'ldap') {
	my $str = "$proto://fixture:unused\@localhost/test";
	my $dbh = bless { AutoCommit => 1 }, 'UserdbFixture';
	local %main::connect_userdb_cache = ( $str => [ $dbh ] );
	local %main::connect_userdb_cache_time = ( $str => time() );
	main::disconnect_userdb($str, $dbh);
	ok(!$dbh->{'commits'} && !$dbh->{'closed'}, "$proto cached release retains handle");
	main::disconnect_userdb($str, $dbh, 1);
	ok(!$dbh->{'commits'} && $dbh->{'closed'}, "$proto closes without a commit");
	is($dbh->{'unbound'}, 1, 'LDAP unbinds before closing') if ($proto eq 'ldap');
}

# Commit failures must be reported and the failed handle must not be reused.
{
	my $str = 'postgresql://fixture:unused@localhost/test';
	my $dbh = bless { AutoCommit => 0, fail => 1 }, 'UserdbFixture';
	local %main::connect_userdb_cache = ( $str => [ $dbh ] );
	local %main::connect_userdb_cache_time = ( $str => time() );
	eval { main::disconnect_userdb($str, $dbh); };
	like($@, qr/deferred constraint failed/, 'commit failure is reported');
	ok($dbh->{'closed'}, 'failed connection is closed');
	ok(!exists($main::connect_userdb_cache{$str}), 'failed connection is removed from cache');
}
done_testing();
