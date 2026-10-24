#!/usr/bin/perl
# Exercise database CGIs without a database server or filesystem side effects.
use strict;
use warnings;
use Test::More;
use FindBin;
use Cwd qw(abs_path);
use JSON::PP;

my $root = abs_path("$FindBin::Bin/..");
require "$root/web-lib-funcs.pl";
my $payload = q{x'"><svg/onload=alert(1)>};
my @names = ('app_data', q{O'Reilly & "Sons"}, $payload);

# render(page, case) runs each CGI in a fresh process to isolate its globals.
sub render
{
my ($page, $case) = @_;
open(my $pipe, '-|', $^X, "$root/t/fixtures/mysql-escaping-render.pl",
	$root, $page, encode_json($case)) or die $!;
my $out = do { local $/; <$pipe> };
close($pipe) or die "Renderer failed for $page: $?";
my $result = decode_json($out);
is($result->{'error'}, '', "$page renders without errors");
return $result;
}

# check_html(html, label) rejects injected tags and event attributes.
sub check_html
{
my ($html, $label) = @_;
# Ignore attribute contents: a literal '<' inside a quoted value is inert.
$html =~ s/"[^"]*"|'[^']*'//g;
unlike($html, qr/<svg\b|\bonload\s*=/i, "$label treats names as text");
}

subtest 'database forms and confirmation pages' => sub {
	for my $name (@names) {
		for my $page (qw(csv_form edit_table edit_field edit_index edit_view
			table_form edit_dbase drop_tables drop_dbase backup_form search_form)) {
			my %in = ( d => '*'.$name, view => $name, index => $name );
			my $r = render($page, { name => $name, in => \%in });
			check_html($r->{'html'}, $page);
			like($r->{'html'}, qr/\Q@{[main::html_escape($name)]}\E/,
				"$page escapes the displayed name");
			is($r->{'input'}->{'db'}, $name, "$page keeps the raw database name");
			is($r->{'input'}->{'table'}, $name, "$page keeps the raw table name");
			for my $args (@{$r->{'structures'}}) {
				is_deeply($args, [ $name, $name ], 'Schema lookup receives original names');
				}
			if ($page ne 'edit_dbase') {
				like($r->{'html'}, qr/\Qdb=@{[main::urlize($name)]}\E/,
					"$page encodes the database in navigation URLs");
				}
			if ($page eq 'csv_form' || $page eq 'backup_form') {
				my $action = $page eq 'csv_form' ? 'csv.cgi/' : 'backup_db.cgi/';
				like($r->{'html'}, qr/\Q$action@{[main::urlize($name)]}\E/,
					'Export action encodes the filename segment');
				}
			}
		}
	};

subtest 'listing layouts, searches and privilege names' => sub {
	for my $style (0..2) {
		for my $page ('index', 'edit_dbase') {
			my $r = render($page, { name => $payload, display => { style => $style } });
			check_html($r->{'html'}, "$page layout $style");
			like($r->{'html'}, qr/\Qdb=@{[main::urlize($payload)]}\E/,
				'Database links encode the name');
			}
		}
	for my $case (
		[ 'edit_dbase', { in => { search => $payload } } ],
		[ 'edit_field', { in => { type => $payload } } ],
		[ 'drop_dbase', { access => { delete => 0 } } ],
		[ 'drop_tables', { in => { d => $payload } } ],
		[ 'edit_cpriv', { in => { table => undef }, access => { perms => 1 } } ],
		[ 'edit_cpriv', { access => { perms => 1 } } ],
		[ 'edit_tpriv', { access => { perms => 1 } } ],
		[ 'edit_tpriv', { in => { db => undef }, access => { perms => 1 } } ],
		[ 'exec', {} ],
		[ 'root_form', { access => { perms => 1 } } ],
		[ 'root_form', { access => { perms => 1 }, socket => 1 } ],
		[ 'list_procs', { access => { perms => 1 } } ]) {
		my $r = render($case->[0], { name => $payload, %{$case->[1]} });
		check_html($r->{'html'}, $case->[0]);
		like($r->{'html'}, qr/\Q@{[main::html_escape($payload)]}\E/,
			'Name remains visible as text');
		}
	};

subtest 'table data, column names and shared PostgreSQL pages' => sub {
	for my $module ('mysql', 'postgresql') {
		for my $name (@names) {
			for my $extra (
				{ in => { start => 2 } },
				{ in => { row => 0 }, display => { add_mode => 1 } },
				{ in => { new => 1 } },
				{ blob => 1, display => { blob_mode => 1 } },
				{ in => { field => $name, for => $name, sortfield => $name, sortdir => $payload } },
				{ in => { advanced => 1, field_0 => $name, for_0 => $name, and => $payload } }) {
				my $r = render('view_table', { module => $module, name => $name, %$extra });
				check_html($r->{'html'}, "$module table data");
				like($r->{'html'}, qr/<b>\Q@{[main::html_escape($name)]}\E<\/b>/,
					'Column heading is escaped');
				like($r->{'html'}, qr/\Qsortfield=@{[main::urlize($name)]}\E/,
					'Sort link encodes column name');
				for my $query (@{$r->{'queries'}}) {
					is($query->[0], $name, 'SQL receives the raw database name');
					like($query->[1], qr/\Q$name\E/, 'SQL retains the raw table name');
					}
				}
			my $r = render('search_form', { module => $module, name => $name,
				access => { edonly => 1 } });
			check_html($r->{'html'}, "$module search form");
			}
		}
	};

subtest 'backup, import and CSV result pages' => sub {
	for my $name ('app_data', $payload) {
		for my $page ('backup_db', 'csv', 'exec_file', 'import') {
			my $r = render($page, { name => $name, in => { dest => $page eq 'csv' ? 1 : 0 } });
			check_html($r->{'html'}, $page);
			like($r->{'html'}, qr/<tt>[^<]*\Q@{[main::html_escape($name)]}\E/,
				"$page escapes displayed filenames");
			if ($page eq 'backup_db') {
				is($r->{'backups'}->[0]->[0], $name, 'Backup receives raw database name');
				like($r->{'backups'}->[0]->[1], qr/\Q$name\E$/, 'Backup receives raw file path');
				}
			if ($page eq 'csv') {
				my $download = render('csv', { name => $name });
				is($download->{'html'}, "Content-type: text/plain\n\n".$r->{'csv'},
					'CSV download and saved bytes match; no HTML escaping of data');
				}
			}
		}
	};

subtest 'restricted access still rejects other databases' => sub {
	open(my $pipe, '-|', $^X, "$root/t/fixtures/mysql-escaping-render.pl",
		$root, 'edit_table', encode_json({ name => $payload, access => { dbs => 'allowed' } })) or die $!;
	my $r = decode_json(do { local $/; <$pipe> });
	close($pipe) or die $?;
	ok($r->{'error'}, 'Unauthorized database is rejected');
	is($r->{'html'}, '', 'No database page is rendered');
	is_deeply($r->{'structures'}, [], 'No schema is queried');
	my $allowed = render('edit_table', { name => $payload,
		in => { db => 'allowed' }, access => { dbs => 'allowed' } });
	check_html($allowed->{'html'}, 'Malicious table name in an allowed database');
	};

done_testing();
