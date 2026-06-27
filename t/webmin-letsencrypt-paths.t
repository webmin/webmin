#!/usr/bin/perl
# Regression tests for Certbot output path parsing used by Webmin SSL.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;

our %config;
our $module_config_directory = "/etc/webmin/webmin";

sub has_command { return undef; }

my $script = File::Spec->rel2abs(
	File::Spec->catfile(dirname(__FILE__), '..',
			    'webmin', 'letsencrypt-lib.pl'));
do $script or die "failed to load $script: $@ $!";

my $certbot_out = <<'EOF';
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/test.example/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/test.example/privkey.pem
This certificate expires on 2026-09-25.
EOF

is(main::get_letsencrypt_output_pem_path($certbot_out),
   '/etc/letsencrypt/live/test.example/fullchain.pem',
   'certbot output path stops at the first PEM path');

my $ipv6_out = <<'EOF';
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/2001:db8::1/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/2001:db8::1/privkey.pem
EOF

is(main::get_letsencrypt_output_pem_path($ipv6_out),
   '/etc/letsencrypt/live/2001:db8::1/fullchain.pem',
   'IPv6 certificate names can still contain colons');

my $wrapped_out = <<'EOF';
Certificate is saved at: /etc/letsencrypt/live/wrapped.example/
 fullchain.pem
EOF

is(main::get_letsencrypt_output_pem_path($wrapped_out),
   '/etc/letsencrypt/live/wrapped.example/fullchain.pem',
   'wrapped PEM paths are normalized');

done_testing();
