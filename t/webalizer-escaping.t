#!/usr/bin/perl
# Verify log paths remain data in Webalizer pages, errors and report output.
use strict;
use warnings;
use Test::More;
use FindBin;
use JSON::PP;

my $root = "$FindBin::Bin/..";
require "$root/web-lib-funcs.pl";
require "$root/ui-lib.pl";

# render_cgi(page, case) runs each CGI in isolation and returns its response.
sub render_cgi
{
my ($page, $case) = @_;
open(my $pipe, '-|', $^X, "$root/t/fixtures/webalizer-escaping-render.pl",
	$root, $page, encode_json($case)) or die $!;
my $json = do { local $/; <$pipe> };
close($pipe) or die "Fixture failed for $page";
return decode_json($json);
}

# path_markup(html) ignores text inside quoted attributes, where '<' is data.
sub path_markup
{
my ($html) = @_;
$html =~ s/"[^"]*"|'[^']*'//g;
return $html;
}

for my $page (qw(edit_log edit_global save_log index)) {
	subtest "$page log paths" => sub {
		for my $name ('access.log', q{access '" & log}, 'access&lt;log&gt;',
			q{<svg onload=alert(1)>}, 'long-'.('x' x 50).q{<svg onload=alert(1)>}) {
			my $r = render_cgi($page, {name => $name});
			is($r->{'error'}, '', 'the page renders successfully');
			is($r->{'input'}->{'file'}, $r->{'file'}, 'the input path is unchanged');
			my $label = $r->{'file'};
			$label = '...'.substr($label, -40) if $page eq 'index' && length($label) > 40;
			$label = main::html_escape($label);
			$label = "<tt>$label</tt>" if $page ne 'index';
			like($r->{'html'}, qr/\Q$label\E/, 'the displayed path is escaped once');
			unlike(path_markup($r->{'html'}), qr/<svg\b/i, 'no injected SVG element');
			if ($page eq 'edit_log') {
				like($r->{'html'}, qr/\Q@{[main::html_escape($r->{'rotated'})]}\E/,
					'rotated log paths are escaped');
				like($r->{'html'}, qr/\Q@{[main::ui_hidden('file', $r->{'file'})]}\E/,
					'the form preserves the original path');
				}
			if ($page eq 'save_log') {
				is_deeply($r->{'reports'}, [[$r->{'file'}, 1]],
					'report generation receives the raw path and HTML escape flag');
				like($r->{'html'}, qr/\Qview_log.cgi\/@{[main::urlize(main::urlize($r->{'file'}))]}\E/,
					'the report URL still encodes the original path twice');
				}
			}
		};
	}

subtest 'related list and missing-file paths' => sub {
	my $r = render_cgi('edit_log', {name => 'access.log', rotation => '.1<svg onload=alert(1)>'});
	is($r->{'error'}, '', 'a hostile rotation filename renders');
	like($r->{'html'}, qr/\Q@{[main::html_escape($r->{'rotated'})]}\E/, 'rotation names are escaped independently');
	$r = render_cgi('index', {name => '<svg onload=alert(1)>', access => {view => 1}});
	is($r->{'error'}, '', 'the view-only index renders');
	unlike(path_markup($r->{'html'}), qr/<svg\b/i, 'view-only paths cannot inject markup');
	for my $page (qw(edit_log save_log)) {
		$r = render_cgi($page, {name => '<svg onload=alert(1)>', no_config => 1, missing => 1});
		is($r->{'error'}, '', "$page handles an unconfigured missing log");
		like($r->{'html'}, qr/\Q@{[main::html_escape($r->{'file'})]}\E/, 'the missing path is escaped');
		unlike(path_markup($r->{'html'}), qr/<svg\b/i, 'the missing path cannot inject markup');
		}
	for my $escape (0, 1) {
		$r = render_cgi('generate_report', {name => '<svg onload=alert(1)>', missing => 1, escape => $escape});
		is($r->{'error'}, '', 'the missing-file report branch returns normally');
		my $message = "Log file $r->{'file'} does not exist\n";
		is($r->{'html'}, $escape ? main::html_escape($message) : $message,
			$escape ? 'browser output is escaped' : 'command-line output remains plain text');
		}
	for my $case ({failed => 1}, {no_report => 1}) {
		$r = render_cgi('save_log', {name => 'access.log', %$case});
		is($r->{'error'}, '', 'report generation finishes normally');
		like($r->{'html'}, $case->{'failed'} ? qr/Webalizer failed!/ : qr/no report was generated/,
			'the report result message is unchanged');
		unlike($r->{'html'}, qr/href='view_log\.cgi\//, 'no report link is offered');
		}
	};

subtest 'report errors and return links' => sub {
	for my $case ({no_config => 1}, {no_report => 1}) {
		my $r = render_cgi('view_log', {name => '<svg onload=alert(1)>', %$case});
		my $path = $case->{'no_config'} ? $r->{'file'} : "$r->{'report_dir'}/index.html";
		like($r->{'error'}, qr/\Q@{[main::html_escape($path)]}\E/, 'the error escapes its path');
		unlike($r->{'error'}, qr/<svg\b/i, 'the error cannot inject markup');
		}
	for my $case ({}, {raw_quote => 1}, {decoded_path => 1}) {
		my $r = render_cgi('view_log', {name => q{access " onfocus="alert(1)}, %$case});
		is($r->{'error'}, '', 'the report renders');
		like($r->{'html'}, qr/Report body/, 'report contents are unchanged');
		like($r->{'html'}, qr/\Qhref="\/webalizer\/edit_log.cgi?file=@{[main::urlize($r->{'file'})]}"\E/,
			'the footer encodes the decoded path as a query value');
		unlike(path_markup($r->{'html'}), qr/\bonfocus\s*=/i,
			'the path cannot add an event handler to the return link');
		}
	};

subtest 'access checks remain enforced' => sub {
	for my $page (qw(edit_log edit_global save_log view_log)) {
		my $r = render_cgi($page, {name => '<svg onload=alert(1)>', access => {dir => ''}});
		isnt($r->{'error'}, '', "$page rejects a disallowed directory");
		is($r->{'html'}, '', 'no page is rendered');
		is_deeply($r->{'reports'}, [], 'no report is generated');
		}
	for my $page (qw(edit_log edit_global save_log)) {
		my $r = render_cgi($page, {name => 'access.log', access => {view => 1}});
		isnt($r->{'error'}, '', "$page rejects view-only access");
		is($r->{'html'}, '', 'no editing page is rendered');
		is_deeply($r->{'reports'}, [], 'no report is generated');
		}
	};

done_testing();
