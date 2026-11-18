#!/usr/bin/perl
# Samba share parsing and connection removal checks.

use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename qw(dirname);
use File::Spec;
use File::Temp qw(tempdir);
use Cwd qw(abs_path);

BEGIN {
	# Stub the load-time dependencies of samba-lib.pl so that its helpers
	# can be tested without a Webmin installation or Samba.
	$INC{'WebminCore.pm'} = 1;
	package WebminCore;
	sub import
	{
	my $caller = caller;
	no strict 'refs';
	*{$caller.'::init_config'} = sub { };
	*{$caller.'::get_module_acl'} = sub { return ( ); };
	*{$caller.'::has_command'} = sub { return undef; };
	*{$caller.'::open_readfile'} = sub {
		my ($fh, $file) = @_;
		$fh = "main::$fh" if (!ref($fh) && $fh !~ /::/);
		return open($fh, "<", $file);
		};
	*{$caller.'::error'} = sub { die "ERROR: $_[0]\n"; };
	*{$caller.'::text'} = sub { return join(" ", @_); };
	*{$caller.'::html_escape'} = sub { return $_[0]; };
	}
}

my $root = abs_path(File::Spec->catdir(dirname(__FILE__), '..'));
chdir($root) or die "chdir($root): $!";
do './samba/samba-lib.pl' or die $@ || $!;
%main::text = ( 'share_evalue' => 'share_evalue' );

my $tmp = tempdir(CLEANUP => 1);
my $conf = "$tmp/smb.conf";
open(my $fh, '>', $conf) or die $!;
print $fh "[global]\r\n\tworkgroup = HOME\r\n\tread only = no\r\n",
	  "[my share]\r\n\tpath = /srv/share\r\n\tprintable = no\r\n",
	  "[printer]\r\n\tpath = /var/spool\r\n\tprintable = yes\r\n";
close($fh);
$main::config{'smb_conf'} = $conf;

subtest 'CRLF configuration files can still be saved' => sub {
	for my $name ('global', 'my share') {
		local %main::share;
		ok(main::get_share($name), "$name is found");
		ok(!(grep { /\r/ } values(%main::share)),
		   "$name values have no carriage return");
		eval { main::check_share_fields($name) };
		is($@, '', "$name passes the field check");
		}
	local %main::share;
	main::get_share('global');
	is($main::share{'workgroup'}, 'HOME', 'values are read in full');
	$main::share{'workgroup'} = "HOME\r[pwn]";
	eval { main::check_share_fields('global') };
	like($@, qr/share_evalue/, 'a carriage return from a form is refused');
};

done_testing();
