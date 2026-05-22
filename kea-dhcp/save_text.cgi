#!/usr/local/bin/perl
# Save a raw Kea file.

use strict;
use warnings;
require './kea-dhcp-lib.pl';
&ReadParseMime();
our (%in, %text);
&error_setup($text{'eacl_aviol'});
&kea_assert_acl('manual');

my $info = &kea_manual_edit_file($in{'file'});
&error($text{'save_efile'}) if (!$info);
my $file = $info->{'file'};
&error($text{'save_efile'}) if (!$file);

&error_setup($text{'save_failsave'});
if ($info->{'type'} eq 'config') {
	# Raw Kea config edits still get parsed before writing so a typo does
	# not leave the daemon with unreadable JSON.
	my $c = $info->{'component'};
	my $data = eval { &kea_parse_config_text($in{'data'}, $file) };
	&error(&text('save_eparse', $@)) if ($@);
	&error(&text('parse_eroot', $c->{'root'}))
		if (ref($data->{$c->{'root'}}) ne 'HASH');
	}

# Write via Webmin's tempfile helpers to preserve the normal locking behavior.
my $existed = -e $file;
&lock_file($file);
my $fh;
&open_tempfile($fh, ">$file");
&print_tempfile($fh, $in{'data'});
&close_tempfile($fh);
&unlock_file($file);
if ($info->{'type'} eq 'password' && !$existed) {
	# New Control Agent password files should inherit the config directory
	# group and be readable only by root plus that group.
	my @dst = stat(&kea_dirname($file));
	chown(-1, $dst[5], $file) if (@dst);
	chmod(0640, $file);
	}

my %log = %in;
delete($log{'data'});
&webmin_log("modify", "config", $file, \%log);
&redirect("");
