#!/usr/bin/perl
BEGIN {
	push(@INC, "..");
	push(@INC, "../vendor_perl");
	push(@INC, "/usr/libexec/webmin/vendor_perl");
};
use Config::IniFiles;
my $cfg = Config::IniFiles->new( -file => '/etc/sysconfig/displaymanager', -fallback => 'GENERAL' );
$cfg->setval('GENERAL', 'DISPLAYMANAGER_REMOTE_ACCESS', '"yes"');
$cfg->newval('GENERAL', 'DISPLAYMANAGER_REMOTE_ACCESS', '"yes"');
$cfg->RewriteConfig;
