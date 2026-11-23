#!/usr/bin/perl
# Search text and paging offsets in the table viewer shared by the MySQL and
# PostgreSQL modules must never be able to add SQL of their own.
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename qw(dirname);
use Cwd qw(abs_path);

my $root = abs_path(dirname(__FILE__)."/..");
do "$root/mysql/view-lib.pl" or die $@ || $!;
$main::displayconfig{'perpage'} = 25;

# read_constant(sql, backslash-escapes)
# Reads one string constant from the start of the SQL, the way a database
# does with or without backslash escapes. Returns its value and the SQL left
# after it, or undef if the constant never ends.
sub read_constant
{
my ($sql, $escapes) = @_;
$sql =~ s/^E?'// or return (undef, $sql);
my $value = '';
while(length($sql)) {
	if ($escapes && $sql =~ s/^\\(.)//s) {
		$value .= $1;
		}
	elsif ($sql =~ s/^''//) {
		$value .= "'";
		}
	elsif ($sql =~ s/^'//) {
		return ($value, $sql);
		}
	else {
		$value .= substr($sql, 0, 1, '');
		}
	}
return (undef, '');
}

# read_value(sql, backslash-escapes)
# Reads a quoted value or the MySQL CONCAT form used for backslashes.
sub read_value
{
my ($sql, $escapes) = @_;
if ($sql =~ s/^concat\(//) {
	my $value = '';
	while(1) {
		my ($part, $rest) = read_constant($sql, $escapes);
		return (undef, $sql) if (!defined($part));
		$value .= $part;
		if ($rest =~ s/^,char\(92\),//) {
			$value .= "\\";
			$sql = $rest;
			}
		elsif ($rest =~ s/^\)//) {
			return ($value, $rest);
			}
		else {
			return (undef, $rest);
			}
		}
	}
return read_constant($sql, $escapes);
}

my @hostile = ( q{plain}, q{it's}, q{say "hi"}, q{x' or '1'='1},
		q{x" or "1"="1}, q{x\' or 1=1 -- }, q{x\\' or 1=1 -- },
		q{\\}, q{\\\\}, q{end\\}, q{'}, q{''}, q{\\''},
		q{5 or 1=1}, q{0; drop table t}, q{a%b_c}, q{} );

foreach my $module ('mysql', 'postgresql') {
	$main::module_name = $module;
	my $prefix = $module eq 'mysql' ? "" : "E";

	# Every search mode writes the text as one complete SQL value
	foreach my $for (@hostile) {
		foreach my $match (0 .. 5) {
			my $sql = main::make_like($match, $for);
			$sql =~ s/^(?:not )?like |^[<>] // or
				fail("$module mode $match starts as expected");
			like($sql, qr/^(?:\Q$prefix\E'|concat\()/,
			     "$module mode $match quotes ".
			     "the text for [$for]");
			my $executed = $sql;
			$executed =~ s/\\/\\\\/g if ($module eq 'postgresql');
			foreach my $escapes (0, 1) {
				# PostgreSQL always reads an E constant
				# with backslash escapes
				next if ($module ne 'mysql' && !$escapes);
				my ($value, $rest) =
					read_value($executed, $escapes);
				is($rest, '', "$module mode $match leaves ".
				   "no SQL after the text for [$for]".
				   ($escapes ? "" : " without escapes"));
				next if (!$escapes && $executed !~ /^concat\(/);
				my $want = $match == 0 || $match == 2 ?
					"%$for%" : $for;
				$want =~ s/\\/\\\\/g
					if ($match == 0 || $match == 2);
				is($value, $want, "$module mode $match ".
				   "keeps the text for [$for]");
				}
			}
		}
	is(main::make_like(6, "x' or 1=1"), " = ''",
	   "$module empty comparison ignores the text");
	is(main::make_like(4, '7.5'), '> 7.5',
	   "$module decimal comparison stays numeric");
	is(main::make_like(5, '-2'), '< -2',
	   "$module negative comparison stays numeric");
	is(main::make_like(4, "7.5\n"), "> ".$prefix."'7.5\n'",
	   "$module number ending in a newline is quoted");
	like(main::make_like(4, '7.5 or 1=1'),
	     qr/^> (?:E)?'7\.5 or 1=1'$/,
	     "$module nonnumeric comparison is quoted");

	# Only a whole number can be an offset
	my ($ok, $zero) = $module eq 'mysql' ?
		("limit 50,25", "limit 0,25") :
		("limit 25 offset 50", "limit 25 offset 0");
	is(main::get_search_limit({ 'start' => '50' }), $ok,
	   "$module offset is used");
	foreach my $start ('', '0;drop table t', '5 union select 1', '-5',
			   '1,2', "1\n2", 'abc') {
		is(main::get_search_limit({ 'start' => $start }), $zero,
		   "$module offset [$start] is ignored");
		}
	local $main::displayconfig{'perpage'} = '25; drop table t';
	like(main::get_search_limit({ 'start' => '50' }), qr/^[a-z0-9 ,]+$/,
	     "$module page size is a number");
	}

done_testing();
