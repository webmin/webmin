#!/usr/bin/perl
# Render printer CGIs with real UI helpers and isolated CUPS queue output.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use FindBin;
use File::Temp qw(tempdir);

my $root = "$FindBin::Bin/..";
require "$root/web-lib-funcs.pl";
require "$root/ui-lib.pl";
$INC{'./lpadmin-lib.pl'} = 1;
*main::ReadParse = sub { };
*main::error = sub { die join(' ', @_)."\n" };
*main::ui_print_header = sub { print main::ui_post_header($_[0]) };
*main::ui_print_footer = sub { };
*main::get_module_variable = sub { return \%main::text };
*main::make_date = sub { '<span data-file-size-bytes="123">Fixture date</span>' };

open(my $lang, '<', "$root/lpadmin/lang/en") or die $!;
while (<$lang>) {
	$main::text{$1} = $2 if /^(\S+)=(.*)$/;
	}
close($lang);

# Load the real parser and access check without module initialization.
for my $source ([ 'cups-lib.pl', 'get_jobs' ],
		[ 'lpadmin-lib.pl', 'can_edit_jobs' ]) {
	open(my $fh, '<', "$root/lpadmin/$source->[0]") or die $!;
	my $code = do { local $/; <$fh> };
	$code =~ /(^sub \Q$source->[1]\E\n\{.*?^\})/ms or die "Missing $source->[1]";
	eval 'no strict; no warnings; '.$1;
	die $@ if $@;
	}

# Keep spool reads and the lpq subprocess inside temporary test fixtures.
my $spool = tempdir('webmin-printer-tests.XXXXXX', DIR => '/tmp', CLEANUP => 1);
open(my $job, '>', "$spool/d00012-001") or die $!;
print $job "Fixture print data\n";
close($job);
$main::lpq = main::quote_path($^X).' '.main::quote_path("$root/t/fixtures/lpadmin-lpq.pl");
$main::config{'spool_dir'} = $spool;

# render_cgi(file, name, access) captures a real CGI without submitting jobs.
sub render_cgi
{
my ($file, $name, $access) = @_;
local %main::in = ( name => $name );
local %main::access = %$access;
local @main::tds;
local $main::printfile;
my $html = '';
open(my $out, '>', \$html) or die $!;
{
	local *STDOUT = $out;
	do "$root/lpadmin/$file.cgi";
	die $@ if $@;
	}
close($out);
return $html;
}

# check_inert(html, label) checks tags and attributes outside quoted values.
sub check_inert
{
my ($html, $label) = @_;
$html =~ s/"[^"]*"|'[^']*'//g;
unlike($html, qr/<(?:img|svg)\b/i, "$label cannot add active elements");
unlike($html, qr/\bon(?:error|load|focus|mouseover)\s*=/i,
	"$label cannot add event attributes");
}

subtest 'test form printer names' => sub {
	for my $name ('Office_Main', q{O'Reilly & Sons},
		q{x'><svg onload="alert(1)"></svg>},
		q{x" autofocus onfocus="alert(1)}) {
		my $html = render_cgi('test_form', $name, { test => 1 });
		check_inert($html, 'Printer name');
		like($html, qr/\Q@{[main::ui_hidden('name', $name)]}\E/,
			'Hidden field uses the attribute-escaping helper');
		my $desc = main::text('test_desc', '<tt>'.main::html_escape($name).'</tt>');
		like($html, qr/\Q$desc\E/,
			'Description preserves trusted formatting and escapes the name');
		like($html, qr/action=test_print\.cgi method=post/,
			'Test-page submission target is unchanged');
		}
	my $ok = eval { render_cgi('test_form', 'Office_Main', { test => 0 }); 1 };
	ok(!$ok, 'Test-print permission remains required');
	like($@, qr/\Q$main::text{'test_ecannot'}\E/, 'Permission error is unchanged');
	};

subtest 'CUPS job titles and queue controls' => sub {
	for my $title ('Quarterly report.pdf', q{Report's "draft" & notes.txt},
		q{<svg onload="alert(1)"></svg>}) {
		local $ENV{'WEBMIN_TEST_PRINT_TITLE'} = $title;
		for my $access ({ cancel => 0 }, { cancel => 1, user => '*' },
			{ cancel => 1, user => 'someone-else' }) {
			my $html = render_cgi('list_jobs', 'Office_Main', $access);
			check_inert($html, 'Job title');
			like($html, qr/\Q@{[main::html_escape($title)]}\E/,
				'Parsed title is displayed as text');
			like($html, qr/<span data-file-size-bytes="123">Fixture date<\/span>/,
				'Trusted date markup still renders normally');
			my $editable = $access->{'cancel'} && $access->{'user'} eq '*';
			is($html =~ /href='view_job\.cgi\?/ ? 1 : 0, $editable ? 1 : 0,
				'Job viewing still follows access permissions');
			is($html =~ /type=['"]?checkbox\b/ ? 1 : 0, $editable ? 1 : 0,
				'Job cancellation still follows access permissions');
			}
		}
	};

subtest 'job-view URLs and empty queues' => sub {
	my $name = q{x'><svg onload="alert(1)"></svg>};
	local $ENV{'WEBMIN_TEST_PRINT_TITLE'} = 'Report.pdf';
	my $html = render_cgi('list_jobs', $name, { cancel => 1, user => '*' });
	check_inert($html, 'Job-view printer name');
	like($html, qr/\Qhref='view_job.cgi?name=@{[main::urlize($name)]}&id=12'\E/,
		'Job-view URL encodes the printer name');
	delete($ENV{'WEBMIN_TEST_PRINT_TITLE'});
	$html = render_cgi('list_jobs', $name, { cancel => 1, user => '*' });
	check_inert($html, 'Empty queue printer name');
	my $desc = main::text('jobs_none', '<tt>'.main::html_escape($name).'</tt>');
	like($html, qr/\Q$desc\E/,
		'Empty queue message remains escaped');
	unlike($html, qr/action="cancel_all\.cgi"/, 'Empty queue has no cancel form');
	};

done_testing();
