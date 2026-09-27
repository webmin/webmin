#!/usr/bin/perl
# Render real selector markup for browser checks, optionally with Cloudmin images.
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/..";
use WebminCore;
our ($root_directory, %text);
$root_directory = "$Bin/..";
$main::ui_page_assets_done = 1;
open(my $lang, '<', "$root_directory/lang/en") or die $!;
while (<$lang>) { $text{$1} = $2 if /^([^=]+)=(.*)/; }
close($lang);
%WebminCore::text = %text;
print '<!doctype html><html><head><meta charset="utf-8">';
print '<link rel="stylesheet" href="file://'.$root_directory.'/unauthenticated/css/ui-lib.css">';
print '<script defer src="file://'.$root_directory.'/unauthenticated/js/ui-lib.js"></script>';
print '<style>html{font:14px Arial,sans-serif}body{margin:0;padding:16px;background:var(--ui-surface);color:var(--ui-fg)}section{margin-bottom:20px}h2{font-size:16px}label{font-weight:400}input[type=checkbox]{accent-color:#2689df}</style></head><body>';

# Grouped options include a disabled choice and enough rows for bulk actions.
my @options = map { { value => "image-$_", label => "Image $_",
	group => { label => $_ < 4 ? 'Recommended' : $_ < 8 ? 'Supported' : 'Older',
		state => $_ < 4 ? 'success' : $_ < 8 ? 'neutral' : 'warning' },
	disabled => $_ == 9,
	metadata => [ { label => '10 GiB', title => 'Minimum disk size: 10 GiB', icon => 'hard-drive' },
		{ label => $_ < 8 ? 'Support until 2030' : 'Support ended 2025',
			icon => 'clock', state => $_ < 8 ? 'neutral' : 'warning' } ] }
} 0..9;
print '<form id="checks"><section>';
print ui_multi_select_list('grouped', ['image-0'], \@options,
	{ compact => 1, search => 1, summary => 'Images', height => '420px' });
print '</section><section>';

# Virtualmin's domain picker uses hierarchy, suffixes, tags and child folding.
my @domains = (
	{ value => 'parent', label => 'example.test' },
	{ value => 'child', label => 'shop', suffix => '.example.test', level => 1 },
	{ value => 'disabled', label => 'disabled.test', tag => 'Disabled' },
	map { { value => "domain-$_", label => "site$_.test" } } 1..7
);
$text{'browser_child_note'} = '+$1 subdomains';
$WebminCore::text{'browser_child_note'} = $text{'browser_child_note'};
print ui_multi_select_list('domains', ['parent', 'child'], \@domains,
	{ search => 1, modes => { name => 'domain_mode', value => 0,
		options => [[0, 'Selected servers'], [1, 'All servers']], hide => [1] },
	  children => { name => 'fold', checked => 1, label => 'Hide subdomains', note => 'browser_child_note' } });
print '</section><section>';

# Legacy positional callers preserve selected labels and prepend new selections.
print ui_multi_select_list('legacy', [['b', 'Chosen B'], ['a', 'Chosen A']],
	[[a => 'A'], [b => 'B'], [c => 'C']], 8);
print '</section><section>';

# Badges and compact rows must preserve both levels of child indentation.
my @nested = map { { value => "nested-$_", label => "Level $_", level => $_,
	group => { label => $_ ? 'Children' : 'Parents' },
	badges => [[ 'Status', 'neutral' ]],
	metadata => [{ label => 'Details', title => 'Literal &amp; <tip> "quoted"' }] }
} 0..2;
foreach my $compact (0, 1) {
	print ui_multi_select_list('nested'.$compact, [], \@nested,
		{ compact => $compact, search => 1, bulk => 0, count => 0,
		  summary => 'Nested choices',
		  children => { name => 'fold'.$compact, checked => 1, label => 'Hide children' } });
}
print '</section><button type="reset">Reset</button></form>';

# Optional preview uses the actual Cloudmin helper and host-filtered catalogue.
if (my $cloudmin = $ARGV[0]) {
	open($lang, '<', "$cloudmin/lang/en") or die $!;
	while (<$lang>) { $text{$1} = $2 if /^([^=]+)=(.*)/; }
	close($lang);
	require "$cloudmin/lib/Cloudmin/ImageCatalog.pm";
	require "$cloudmin/cloudmin-pages.pl";
	my $catalogue = Cloudmin::ImageCatalog->new(path => "$cloudmin/catalog/images.json");
	my @images = map { _cloudmin_image_option($_) } @{$catalogue->list_images('aarch64')};
	print '<section id="cloudmin" class="ui_page"><h2>Add images</h2>';
	print ui_multi_select_list('images', [], \@images,
		{ compact => 1, search => 1, bulk => 0, count => 0, height => '650px',
		  summary => $text{'images_bundled_cloud'}, summary_icon => 'download' });
	print '</section>';
}
print '</body></html>';
