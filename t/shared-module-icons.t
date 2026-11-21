#!/usr/bin/perl
use strict;
use warnings;
use Cwd qw(abs_path);
use Digest::SHA;
use File::Find;
use FindBin;
use Test::More;

my $root = abs_path("$FindBin::Bin/..");
chdir($root) or die $!;
opendir(my $dh, '.') or die $!;
my @modules = grep { !/^\./ && !-l $_ && -f "$_/module.info" } readdir($dh);
closedir($dh);
my @paths = grep { -e $_ } ('images', 'gray-theme/unauthenticated/images',
	map { "$_/images" } @modules);

# Compare the actual image data, including module-specific artwork.
my (%seen, @broken, @copies);
find({ no_chdir => 1, wanted => sub {
	my $path = $File::Find::name;
	return if ($path =~ m!/(?:favicons|logos)/! || $path =~ m!/favicon\.\w+\z!i);
	return if ($path !~ /\.(?:gif|png|svg|jpe?g|webp)\z/i);
	if (-l $path) {
		my $target = abs_path($path);
		push(@broken, $path) if (!defined($target) ||
			index($target, "$root/") != 0 || !-f $target);
		return;
		}
	open(my $fh, '<:raw', $path) or die "$path: $!";
	my $hash = Digest::SHA->new(256)->addfile($fh)->hexdigest;
	close($fh);
	push(@copies, "$path = $seen{$hash}") if (exists($seen{$hash}));
	$seen{$hash} = $path;
	} }, @paths);

is_deeply(\@broken, [ ], 'every icon link resolves inside Webmin');
is_deeply(\@copies, [ ], 'each distinct icon is stored once');
# Exercise every declared action through the same lookup as the module grid.
require "$root/web-lib-funcs.pl";
our ($root_directory, @root_directories, $module_name, %gconfig);
$root_directory = $root;
@root_directories = ($root);
$gconfig{'webprefix'} = '/webmin';
$module_name = 'net';
is(module_icon_url('images/ifcs.gif'), '/webmin/images/shared/network-card.svg',
	'Network Configuration resolves the interfaces action used on its index');
my @missing;
my @maps = grep { -f $_ } map { "$root/$_/images/icons.map" } @modules;
foreach my $map (@maps, "$root/images/modules/icons.map") {
	open(my $fh, '<', $map) or die "$map: $!";
	while (<$fh>) {
		chomp;
		my ($name, $file) = split(/=/, $_, 2);
		my ($mod, $action) = $name =~ m!^([^/]+)/(.+)$!;
		if (!$mod) {
			($mod) = $map =~ m!/([^/]+)/images/icons\.map$!;
			$action = $name;
			}
		$module_name = $mod;
		my $expected = $file =~ s!^\./!! ? "/$mod/images/$file" :
			       $file =~ m!^/! ? $file : "/images/shared/$file";
		# Module pages and the top-level index supply different URLs.
		foreach my $input ("images/$action.gif", "$mod/images/$action.gif") {
			my $url = module_icon_url($input);
			push(@missing, "$input -> $url (expected $expected)")
				if ($url ne "/webmin$expected" || !-f "$root$expected");
			}
		}
	close($fh);
	}
is_deeply(\@missing, [ ], 'all module and add-on actions resolve to their declared files');

open(my $mime, '<', 'filemin/mime-icons.map') or die $!;
my @missing_mime;
while (<$mime>) {
	chomp;
	my ($type, $icon) = split(/=/, $_, 2);
	push(@missing_mime, $type) if (!-f "filemin/images/icons/mime/$icon.svg");
	}
is_deeply(\@missing_mime, [ ], 'all MIME names point to packaged File Manager icons');
done_testing();
