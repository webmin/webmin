#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Path qw(make_path);
use File::Temp qw(tempdir);

require "$FindBin::Bin/../web-lib-funcs.pl";
require "$FindBin::Bin/../ui-lib.pl";
our ($root_directory, @root_directories, @theme_root_directories, %gconfig,
     $module_name);
$root_directory = tempdir(CLEANUP => 1);
@root_directories = ( $root_directory );
my $theme = "$root_directory/theme";
@theme_root_directories = ( $theme );
$module_name = 'virtual-server';
$gconfig{'webprefix'} = '/webmin';

# touch(file) creates an empty image file and its directories.
sub touch
{
my ($file) = @_;
(my $dir = $file) =~ s!/[^/]+\z!!;
make_path($dir);
open(my $fh, '>', $file) or die $!;
close($fh) or die $!;
}

# render(url) captures the icon URL an action page sends to the browser.
sub render
{
my ($url) = @_;
my $html;
open(my $out, '>', \$html) or die $!;
local *STDOUT = $out;
&generate_icon($url, 'Service plan', 'edit_plan.cgi');
return ($html =~ /<img src="([^"]+)"/)[0];
}

my $addon = 'third-party';
my $map = "$root_directory/images/modules/icons.map";
make_path("$root_directory/images/modules");
open(my $fh, '>', $map) or die $!;
print $fh "$addon/access=padlock.png\n$addon/lock=padlock.png\n";
close($fh);

my $own = "$root_directory/virtual-server/images";
is(render('images/newplan.gif'), 'images/newplan.gif',
	'keep the URL when no format exists');

# The module's own copy, in SVG, PNG and GIF order.
touch("$own/newplan.gif");
is(render('images/newplan.svg'), 'images/newplan.gif', 'fall back to GIF');
touch("$own/newplan.png");
is(render('images/newplan.gif'), 'images/newplan.png', 'prefer PNG to GIF');
touch("$own/newplan.svg");
is(render('images/newplan.gif'), 'images/newplan.svg', 'prefer SVG to PNG');

# Other modules' images, as requested by the cluster modules.
touch("$root_directory/servers/images/hpux.gif");
is(render('/webmin/servers/images/hpux.svg'), '/webmin/servers/images/hpux.gif',
	'absolute URL falls back to GIF');
is(render('../servers/images/hpux.svg'), '../servers/images/hpux.gif',
	'parent-relative URL falls back to GIF');

# Webmin's copy of an add-on icon wins over the module's own copy.
my $shared = '/webmin/images/modules/virtual-server';
touch("$root_directory/images/modules/virtual-server/newplan.gif");
is(render('images/newplan.gif'), "$shared/newplan.gif",
	'Webmin replaces the add-on icon');
touch("$root_directory/images/modules/virtual-server/newplan.png");
is(render('/webmin/virtual-server/images/newplan.gif'), "$shared/newplan.png",
	'prefix appears once on an absolute URL');
like(&ui_img('images/newplan.gif'), qr!src='\Q$shared\E/newplan\.png'!,
	'small images use the same lookup');

$module_name = '';
is(render('virtual-server/images/newplan.gif'), "$shared/newplan.png",
	'module list icons use the same lookup');
$module_name = 'virtual-server';

# A theme's copy wins over both, even in an older format.
touch("$theme/images/modules/virtual-server/newplan.gif");
is(render('images/newplan.svg'), "$shared/newplan.gif",
	'theme copy takes precedence over Webmin');
touch("$theme/images/modules/servers/hpux.svg");
is(render('/webmin/servers/images/hpux.gif'),
	'/webmin/images/modules/servers/hpux.svg',
	'theme copy takes precedence over the module');

foreach my $url ('/images/left.gif', '../images/left.gif',
		 'images/newplan.gif?v=1', 'images/photo.jpg',
		 'graph.cgi?id=2', 'https://example.org/images/external.png') {
	is(render($url), $url, "preserve $url");
	}
# Two add-on actions use the same stock icon, even if the add-on has its own.
touch("$root_directory/images/shared/padlock.png");
touch("$root_directory/$addon/images/access.svg");
$module_name = $addon;
foreach my $action ('access', 'lock') {
	is(render("images/$action.gif"), '/webmin/images/shared/padlock.png',
		"$action uses the shared file");
	}
touch("$theme/images/modules/$addon/access.gif");
is(render('images/access.gif'), "/webmin/images/modules/$addon/access.gif",
	'the theme overrides one shared action by its original name');
is(render('images/lock.gif'), '/webmin/images/shared/padlock.png',
	'the other action keeps the stock icon');
# A map written for a PNG still resolves after the artwork becomes an SVG.
unlink("$root_directory/images/shared/padlock.png") or die $!;
touch("$root_directory/images/shared/padlock.svg");
is(render('images/lock.gif'), '/webmin/images/shared/padlock.svg',
	'a map naming the older format finds the converted icon');
done_testing();
