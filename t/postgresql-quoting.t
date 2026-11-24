#!/usr/bin/perl
# Shell and SQL quoting in the PostgreSQL module.

use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename qw(dirname);
use File::Spec;
use File::Temp qw(tempdir);
use Cwd qw(abs_path);

BEGIN {
	# Stub the load-time dependencies of postgresql-lib.pl so that its
	# helpers can be tested without a Webmin installation or a database.
	$INC{'WebminCore.pm'} = 1;
	package WebminCore;
	sub import
	{
	my $caller = caller;
	no strict 'refs';
	*{$caller.'::init_config'} = sub { };
	*{$caller.'::get_module_acl'} = sub { return ( ); };
	}
}

my $root = abs_path(File::Spec->catdir(dirname(__FILE__), '..'));
chdir($root) or die "chdir($root): $!";
do './postgresql/postgresql-lib.pl' or die $@ || $!;
$main::module_name = 'postgresql';

# shell_words(command)
# Splits a command into words the way /bin/sh would. The payloads below only
# echo, so a quoting failure shows up as extra words rather than side effects.
sub shell_words
{
my ($cmd) = @_;
open(my $fh, '-|', '/bin/sh', '-c',
     'for a in '.$cmd.'; do printf "%s\0" "$a"; done') or die $!;
local $/;
my $out = <$fh>;
close($fh);
return split(/\0/, $out);
}

subtest 'DBI receives one quoted database name' => sub {
	my $dsn;
	local *TestPgDriver::connect = sub { $dsn = $_[1]; die "captured\n"; };
	local $main::driver_handle = bless { }, 'TestPgDriver';
	local $main::postgres_sameunix = 0;
	local %main::config = ( host => 'localhost', port => 5432 );
	eval { main::execute_sql_safe(q{Sam's sales\archive;2026}, 'select 1') };
	is($dsn, q{dbname='Sam\'s sales\\\\archive;2026';host=localhost;port=5432},
	   'spaces, quotes, backslashes and punctuation stay in the name');
};

subtest 'SQL file runner quotes the database name' => sub {
	no warnings 'redefine';
	my $tmp = tempdir(CLEANUP => 1);
	my $file = "$tmp/input.sql";
	open(my $fh, '>', $file) or die $!;
	print $fh "select 1;\n";
	close($fh);
	my $cmd;
	local $main::postgres_sameunix = 0;
	local $main::postgres_login = 'pg admin;echo x';
	local %main::config = ( 'psql' => '/usr/bin/psql',
				'host' => 'db;echo x',
				'port' => '5432;echo x' );
	local *main::is_readonly_mode = sub { 0 };
	local *main::supports_psql_restrict = sub { 1 };
	local *main::supports_pgpass = sub { 1 };
	local *main::generate_miniserv_websocket_token = sub { 'abc123' };
	local *main::quote_path = sub { "'$_[0]'" };
	local *main::command_with_login = sub { $_[0] };
	local *main::clean_language = sub { };
	local *main::reset_environment = sub { };
	local *main::backquote_logged = sub { $cmd = $_[0]; return ''; };
	my $db = 'x;echo injected;#';
	main::execute_sql_file($db, $file);
	$cmd =~ s/ 2>&1$// or die "Unexpected command $cmd";
	my @words = shell_words($cmd);
	is($words[-1], $db, 'the database is one shell word');
	ok((grep { $_ eq 'pg admin;echo x' } @words),
	   'the login is one shell word');
	ok((grep { $_ eq 'db;echo x' } @words), 'the host is one shell word');
	ok((grep { $_ eq '5432;echo x' } @words), 'the port is one shell word');

	local $main::config{'sslmode'} = 'require';
	main::execute_sql_file($db, $file);
	$cmd =~ s/ 2>&1$//;
	ok((grep { $_ eq 'host=db;echo x port=5432;echo x sslmode=require' }
		 shell_words($cmd)), 'the connection string is one shell word');
};

# sent_sql(sql, [param, ...])
# Returns the SQL that execute_sql_safe would send over DBI.
sub sent_sql
{
my ($sql, @params) = @_;
my $sent;
local *TestPgDbh::prepare = sub { $sent = $_[1]; die "captured\n"; };
local *TestPgDriver::connect = sub { return bless { }, 'TestPgDbh'; };
local $main::driver_handle = bless { }, 'TestPgDriver';
local $main::postgres_sameunix = 0;
local %main::config = ( );
eval { main::execute_sql_safe('db', $sql, @params) };
return $sent;
}

# server_value(sql-literal)
# Reads a sent literal the way PostgreSQL 9.1 and later do. Plain strings keep
# backslashes as they are, while E'...' strings treat them as escapes.
sub server_value
{
my ($lit) = @_;
if ($lit =~ /^'(.*)'$/s) {
	(my $v = $1) =~ s/''/'/g;
	return $v;
	}
$lit =~ /^E'(.*)'$/s or return undef;
my $v = $1;
my %esc = ( 'n' => "\n", 'r' => "\r", 't' => "\t", 'b' => "\b", 'f' => "\f" );
$v =~ s/\\(.)|''/defined($1) ? ($esc{$1} \/\/ $1) : "'"/gse;
return $v;
}

subtest 'Quoted literals reach the server unchanged' => sub {
	foreach my $value ("a\\b", "a\\\\b", "q'\\z", "plain") {
		my $sent = sent_sql("alter user u with password ".
				    main::pg_quote_lit($value));
		my ($lit) = $sent =~ /with password (.*)$/s;
		is(server_value($lit), $value,
		   "the server stores $value exactly");
		}
};

subtest 'psql parameters reach the server unchanged' => sub {
	no warnings 'redefine';
	my $cmd;
	local $main::driver_handle = undef;
	local $main::postgres_sameunix = 0;
	local $main::postgres_login = 'postgres';
	local %main::config = ( 'psql' => '/usr/bin/psql' );
	local *main::quote_path = sub { "'$_[0]'" };
	local *main::supports_pgpass = sub { 1 };
	local *main::foreign_check = sub { 0 };
	local *main::command_with_login = sub {
		$cmd = $_[0];
		return "printf 'x\\n'";
		};
	foreach my $value ("a\\b", "c\$d\ne", "q'\\z") {
		main::execute_sql_safe('db', 'select ?', $value);
		my @words = shell_words($cmd);
		my ($i) = grep { $words[$_] eq '-c' } (0..$#words);
		my ($lit) = $words[$i+1] =~ /^select (.*)$/s;
		is(server_value($lit), $value, "the server reads $value exactly");
		}
};

subtest 'Typed SQL can bypass backslash doubling' => sub {
	is(sent_sql("select 'a\\b'"), "select 'a\\\\b'",
	   'library SQL still has its backslashes doubled');
	local $main::disable_postgresql_escaping = 1;
	is(sent_sql("select 'a\\b'"), "select 'a\\b'",
	   'SQL run with escaping disabled is sent as typed');
	my $src = do { local (@ARGV, $/) = ('postgresql/exec.cgi'); <> };
	like($src, qr/disable_postgresql_escaping = 1;\s*\n\s*\$d = &execute_sql_logged/,
	     'the Execute SQL page runs typed SQL that way');
};

done_testing();
