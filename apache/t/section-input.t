#!/usr/bin/perl
# Tests that per-directory section forms cannot add directives through a
# section type, a path or a document root.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use Cwd qw(abs_path);

my $root = abs_path(File::Spec->catdir(dirname(__FILE__), '..', '..'));
my $tmp = abs_path(tempdir(CLEANUP => 1));
my $webmin_config = "$tmp/webmin-config";
my $webmin_var = "$tmp/webmin-var";
my $apache_root = "$tmp/apache2";
my $apache_conf = "$apache_root/apache2.conf";
my $docroot = "$tmp/www";
make_path($webmin_config, $webmin_var, "$webmin_config/apache",
	  "$webmin_var/apache", $apache_root, $docroot);

# write_text(file, text)
# Writes a fixture file or dies
sub write_text
{
my ($file, $text) = @_;
open(my $fh, '>', $file) || die "Failed to write $file: $!";
print $fh $text;
close($fh) || die "Failed to close $file: $!";
}

# read_text(file)
# Returns the contents of a fixture file
sub read_text
{
my ($file) = @_;
open(my $fh, '<', $file) || die "Failed to read $file: $!";
local $/;
my $text = <$fh>;
close($fh);
return $text;
}

write_text("$webmin_config/config", "os_type=debian-linux\nos_version=12\n");
write_text("$webmin_config/miniserv.conf", "root=$root\n");
write_text("$webmin_config/apache/config",
	"httpd_dir=$apache_root\nhttpd_path=/bin/true\n".
	"httpd_conf=$apache_conf\napachectl_path=/bin/true\n".
	"httpd_version=2.4.57\n");
write_text($apache_conf,
	"Listen 80\n".
	"<VirtualHost *:80>\n".
	"ServerName example.com\n".
	"DocumentRoot $docroot\n".
	"CustomLog /var/log/example.log combined\n".
	"</VirtualHost>\n");

$ENV{'WEBMIN_CONFIG'} = $webmin_config;
$ENV{'WEBMIN_VAR'} = $webmin_var;
$ENV{'FOREIGN_MODULE_NAME'} = 'apache';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $root;
$ENV{'REMOTE_USER'} = 'root';

chdir("$root/apache") || die "chdir: $!";
require './apache-lib.pl';    ## no critic
{
	no warnings 'once';
	$main::error_must_die = 1;
	%main::in = ( );
}

# run_cgi(script, &inputs)
# Runs a CGI with the given inputs, and returns any error
sub run_cgi
{
my ($script, $inputs) = @_;
%main::in = %$inputs;
my $out = '';
no warnings qw(redefine once);
local *main::ReadParse = sub { };
local *main::webmin_log = sub { };
open(my $fh, '>', \$out) || die $!;
my $old = select($fh);
do "./$script";
my $err = $@;
select($old);
close($fh);
&unlock_all_files();
undef(@main::get_config_cache);
%main::file_cache = ( );
return $err;
}

# --- helper checks --------------------------------------------------------
ok(&valid_section_path('/srv/www/a b'), 'a path with a space is accepted');
ok(&valid_section_path('\.php$'), 'a regex path is accepted');
ok(!&valid_section_path("/srv\nCustomLog \"|/bin/sh\" common"),
   'a path with a line break is rejected');
ok(!&valid_section_path('/srv" "/etc'), 'a path with a quote is rejected');
ok(!&valid_section_path('/srv\\'), 'a path with a trailing backslash is rejected');
ok(&valid_section_type($_), "section type $_ is accepted")
	foreach ('Directory', 'Files', 'Location', 'Proxy');
ok(!&valid_section_type("Location \"/\">\nCustomLog"),
   'a section type with extra text is rejected');

# --- create_dir.cgi and change_dir.cgi -------------------------------------
my $conf = &get_config();
my ($vidx) = grep { $conf->[$_]->{'name'} eq 'VirtualHost' } 0 .. $#$conf;
my $err = &run_cgi('create_dir.cgi', { 'virt' => $vidx, 'type' => 'Location',
	'path' => "/x\">\nCustomLog \"|/bin/sh -c id\" common\n<Location \"/y" });
isnt($err, '', 'a Location path with a line break is rejected');
$err = &run_cgi('create_dir.cgi', { 'virt' => $vidx,
	'type' => "Location \"/z\">\nCustomLog \"|/bin/sh -c id\" common\n".
		  "</Location>\n<Location", 'path' => '/z' });
isnt($err, '', 'a section type with a line break is rejected');
unlike(&read_text($apache_conf), qr/bin\/sh/, 'no piped log was added');

$err = &run_cgi('create_dir.cgi', { 'virt' => $vidx, 'type' => 'Location',
				    'path' => '/status' });
is($err, '', 'a Location section is created');
like(&read_text($apache_conf), qr/<Location "\/status">/,
     'the section is written');

# change_dir.cgi must only change sections, not other directives
$conf = &get_config();
my $members = $conf->[$vidx]->{'members'};
my ($logidx) = grep { $members->[$_]->{'name'} eq 'CustomLog' }
		    0 .. $#$members;
$err = &run_cgi('change_dir.cgi', { 'virt' => $vidx, 'idx' => $logidx,
				    'delete' => 1 });
isnt($err, '', 'a directive that is not a section cannot be deleted');
like(&read_text($apache_conf), qr/CustomLog \/var\/log\/example\.log/,
     'the log directive remains');

# --- save_vserv.cgi -------------------------------------------------------
my $baddir = "$tmp/www\nCustomLog |/bin/sh common";
make_path($baddir);
$err = &run_cgi('save_vserv.cgi', { 'virt' => $vidx, 'addr_def' => 2,
				    'port_mode' => 0, 'name_def' => 1,
				    'root' => $baddir, 'old_root' => $docroot });
isnt($err, '', 'a document root with a line break is rejected');
unlike(&read_text($apache_conf), qr/bin\/sh/, 'no directive was added');

done_testing();
