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

done_testing();
