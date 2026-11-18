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
do './mysql/view-lib.pl' or die $@ || $!;
$main::module_name = 'postgresql';

# pg_literal(sql, standard-strings)
# Reads one string constant from the start of the SQL and returns its value
# and the SQL after it. Plain strings only treat backslashes as escapes when
# standard_conforming_strings is off.
sub pg_literal
{
my ($sql, $standard) = @_;
my $escape = $sql =~ s/^E'//;
$escape || $sql =~ s/^'// or return (undef, $sql);
$escape ||= !$standard;
my $value = '';
while(length($sql)) {
	if ($escape && $sql =~ s/^\\(.)//s) {
		$value .= $1;
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

my @values = (
	q{x\' superuser -- },
	q{x' superuser -- },
	"trailing\\",
	"plain",
	"",
	);

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

done_testing();
