#!/usr/bin/perl
# SQL string quoting in the MySQL module and its shared table viewer helpers.

use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename qw(dirname);
use File::Spec;
use Cwd qw(abs_path);

BEGIN {
	# Stub only the load-time dependencies of mysql-lib.pl, as in
	# t/mysql-lib.t, so that its pure helpers can be tested directly.
	$INC{'WebminCore.pm'} = 1;
	$INC{'view-lib.pl'} = 1;
	package WebminCore;
	sub import
	{
	my $caller = caller;
	no strict 'refs';
	*{$caller.'::init_config'} = sub { };
	*{$caller.'::get_module_acl'} = sub { return (bpath => ''); };
	*{$caller.'::read_file_contents'} = sub { return "10.5.29-MariaDB\n"; };
	*{$caller.'::compare_version_numbers'} = sub {
		my @left = split(/\./, $_[0]);
		my @right = split(/\./, $_[1]);
		for(my $i = 0; $i < @left || $i < @right; $i++) {
			my $cmp = ($left[$i] || 0) <=> ($right[$i] || 0);
			return $cmp if ($cmp);
			}
		return 0;
		};
	*{$caller.'::has_command'} = sub { return $_[0]; };
	*{$caller.'::quote_path'} = sub { return $_[0]; };
	*{$caller.'::backquote_command'} = sub { return ''; };
	}
}

my $root = abs_path(File::Spec->catdir(dirname(__FILE__), '..'));
chdir($root) or die "chdir($root): $!";
do './mysql/mysql-lib.pl' or die $@ || $!;
do './mysql/view-lib.pl' or die $@ || $!;
$main::module_name = 'mysql';

# mysql_literal(sql)
# Reads one single-quoted string from the start of the SQL, with MySQL's
# default escapes, and returns its value and the SQL after it.
sub mysql_literal
{
my ($sql) = @_;
$sql =~ s/^'// or return (undef, $sql);
my %esc = ( '0' => "\0", 'n' => "\n", 'r' => "\r", 't' => "\t",
	    'b' => "\b", 'Z' => "\x1a" );
my $value = '';
while(length($sql)) {
	if ($sql =~ s/^\\(.)//s) {
		$value .= exists($esc{$1}) ? $esc{$1} : $1;
		}
	elsif ($sql =~ s/^''//) {
		$value .= "'";
		}
	elsif ($sql =~ s/^'//) {
		return ($value, $sql);
		}
	else {
		$sql =~ s/^(.)//s;
		$value .= $1;
		}
	}
return (undef, $sql);
}

my @values = (
	q{x\' , `root`@`localhost` identified by "pwned" -- },
	q{x\\' or 1=1 -- },
	"trailing\\",
	"it's",
	"\0nul",
	"line\nbreak",
	"",
	"under_score%",
	);

subtest 'DBI receives the database name separately from connection options' => sub {
	my ($dsn, $attrs);
	local *TestMysqlDriver::connect = sub {
		($dsn, $attrs) = @_[1, 4];
		die "captured\n";
		};
	local $main::driver_handle = bless { }, 'TestMysqlDriver';
	local $main::driver_info = { opt => 'mysql' };
	local %main::config = ( host => 'localhost', port => 3306 );
	my $name = 'Sales: Q1;2026';
	eval { main::execute_sql_safe($name, 'select 1') };
	is($dsn, 'host=localhost;port=3306', 'configured host and port are preserved');
	is_deeply($attrs, { database => $name }, 'the driver receives the literal name');
};

subtest 'escaped strings cannot end the quoted value early' => sub {
	for my $value (@values) {
		my ($got, $rest) =
			mysql_literal("'".main::escapestr($value)."' TAIL");
		is($got, $value, 'the value is read back unchanged');
		is($rest, ' TAIL', 'the closing quote is the one added');
		}
};

subtest 'quoting also survives double-quote backslash handling' => sub {
	# execute_sql doubles backslashes between double quotes. That may
	# change a value, but must never end the string early.
	for my $value (@values, q{a"b\\'c" or 1=1 -- }, q{"\\"}) {
		my $sql = main::escape_backslashes_in_quotes(
			"'".main::escapestr($value)."' TAIL");
		my ($got, $rest) = mysql_literal($sql);
		ok(defined($got), 'the value is still one string');
		is($rest, ' TAIL', 'nothing escapes the string');
		}
};

subtest 'command line parameters are quoted the same way' => sub {
	for my $value (@values) {
		my $sql = main::replace_sql_parameters(
			'select ? from t where c = ?', $value, undef);
		$sql =~ s/^select // or die;
		my ($got, $rest) = mysql_literal($sql);
		is($got, $value, 'the parameter is read back unchanged');
		is($rest, ' from t where c = NULL', 'undef becomes NULL');
		}
};

subtest 'password changes quote the account and password' => sub {
	no warnings 'redefine';
	local $main::password_func = 'password';
	local *main::get_account_lock_support = sub { 0 };
	my $user = q{o'neil\\};
	my $host = q{%.example\\'};
	for my $variant ([ '10.5.0', 'mariadb' ], [ '8.0.30', 'mysql' ],
			 [ '5.5.0', 'mysql' ]) {
		local *main::get_remote_mysql_variant = sub { @$variant };
		my $sql = main::get_change_pass_sql($values[0], $user, $host,
						   'mysql_native_password');
		$sql =~ s/^(alter user|set password for) // or
			die "Unexpected SQL $sql";
		my ($gotuser, $rest) = mysql_literal($sql);
		is($gotuser, $user, "@$variant: the user name is quoted");
		$rest =~ s/^\@// or die "No host in $rest";
		my ($gothost, $rest2) = mysql_literal($rest);
		is($gothost, $host, "@$variant: the host is quoted");
		$rest2 =~ s/^.*?(by |password\()'/'/ or
			die "No password in $rest2";
		my ($gotpass, $tail) = mysql_literal($rest2);
		is($gotpass, $values[0], "@$variant: the password is quoted");
		like($tail, qr/^\)?$/,
		     "@$variant: nothing follows the password");
		}
};

subtest 'new MariaDB users quote the account name' => sub {
	no warnings 'redefine';
	my @sql;
	local $main::password_func = 'password';
	local *main::get_account_lock_support = sub { 0 };
	local *main::get_remote_mysql_variant = sub { ('10.6.0', 'mariadb') };
	local *main::execute_sql_logged = sub { push(@sql, $_[1]); };
	local *main::update_privileges = sub { };
	local *main::get_mysql_plugin = sub { '' };
	main::create_user({ 'user' => q{bob'}, 'host' => 'localhost',
			    'pass' => $values[0], 'plugin' => '' });
	my $sql = $sql[0];
	$sql =~ s/^create user // or die "Unexpected SQL $sql";
	my ($gotuser, $rest) = mysql_literal($sql);
	is($gotuser, q{bob'}, 'the user name is quoted');
	$rest =~ s/^\@'localhost' identified by // or die "Unexpected $rest";
	my ($gotpass, $tail) = mysql_literal($rest);
	is($gotpass, $values[0], 'the password is quoted');
	is($tail, '', 'nothing follows the password');
};

subtest 'table searches quote values and offsets' => sub {
	local %main::displayconfig = ( 'perpage' => 25 );
	for my $match (0..5) {
		for my $value (@values,
			       q{x" union select user from mysql.user#}) {
			my $cond = main::make_like($match, $value);
			$cond =~ s/^(not )?(like|>|<) // or
				die "Unexpected $cond";
			my ($got, $rest) = mysql_literal($cond);
			my $want = $match == 0 || $match == 2 ?
				"%$value%" : $value;
			is($got, $want, "mode $match quotes the search value");
			is($rest, '', 'nothing follows the value');
			}
		}
	is(main::get_search_limit({ 'start' => '1;drop table x' }),
	   'limit 0,25', 'a non-numeric offset starts from the first row');
	is(main::get_search_limit({ 'start' => ' 50 ' }), 'limit 50,25',
	   'a numeric offset is kept');
	local $main::module_name = 'postgresql';
	is(main::get_search_limit({ 'start' => '-1' }), 'limit 25 offset 0',
	   'a negative offset starts from the first row');
};

subtest 'restricted grants match only the selected database' => sub {
	local %main::module_info = ( );
	local %main::access = ( 'dbs' => 'my_db _____' );
	ok(main::can_edit_grant_db('my\_db'),
	   'an escaped own database is allowed');
	ok(!main::can_edit_grant_db('my_db'),
	   'a pattern covering other databases is refused');
	ok(!main::can_edit_grant_db('mysql'), 'another database is refused');
	ok(!main::can_edit_grant_db('my%'), 'a wildcard pattern is refused');
	is(main::quote_mysql_database(main::unquote_mysql_database('_____')),
	   '\_\_\_\_\_', 'stored grants escape every wildcard');
	is(main::quote_mysql_database(main::unquote_mysql_database('my\_db')),
	   'my\_db', 'an already escaped name is not escaped twice');
	$main::access{'dbs'} = '*';
	ok(main::can_edit_grant_db('my_db'), 'all-database access allows patterns');
};

subtest 'privilege updates use the supplied account permissions' => sub {
	no warnings 'redefine';
	my @calls;
	local *main::get_remote_mysql_variant = sub { ('5.7', 'mysql') };
	local *main::execute_sql_logged = sub { push(@calls, [ @_ ]); };
	local %main::perms = ( Update_priv => 1 );
	main::update_privileges({
		user => 'test', host => 'localhost', perms => { Select_priv => 1 },
		pfields => [ 'Select_priv', 'Update_priv' ],
		});
	is_deeply([ @{$calls[0]}[2..5] ], [ 'Y', 'N', 'localhost', 'test' ],
		  'only the requested permission is set');
	};

done_testing();
