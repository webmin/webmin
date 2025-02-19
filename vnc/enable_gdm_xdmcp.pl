#!/usr/bin/perl
BEGIN {
	push(@INC, "..");
	push(@INC, "../vendor_perl");
	push(@INC, "vendor_perl");
	push(@INC, "/usr/libexec/webmin/vendor_perl");
};
use Config::IniFiles;
my $cfg = Config::IniFiles->new( -file => '/etc/gdm/custom.conf', -fallback => 'GENERAL' );
$cfg->setval('xdmcp', 'Enable', 'true');
$cfg->newval('xdmcp', 'Enable', 'true');
$cfg->RewriteConfig;
