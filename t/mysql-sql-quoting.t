#!/usr/bin/perl
# Database grant names for restricted MySQL administrators.

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
$main::module_name = 'mysql';

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

done_testing();
