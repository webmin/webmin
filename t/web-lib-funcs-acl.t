#!/usr/bin/perl
# Unit tests for ACL preservation helpers in web-lib-funcs.pl.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;

my $script = File::Spec->rel2abs(
	File::Spec->catfile(dirname(__FILE__), '..', 'web-lib-funcs.pl'));
require $script;

subtest 'physical restore is enabled when supported' => sub {
	no warnings 'redefine';
	my $calls = 0;
	local *main::backquote_command = sub {
		$calls++;
		return "setfacl 2.4.0 -- set file access control lists\n".
		       "Usage: setfacl [-bkndRLP] { -m|-M|-x|-X ... } file ...\n".
		       "       setfacl [-P] --restore=file\n".
		       "  -P, --physical          physical walk, do not follow symbolic links\n".
		       "      --restore=file      restore ACLs (inverse of `getfacl -R')\n";
		};

	is(main::get_setfacl_restore_command('/usr/bin/setfacl'),
	   '/usr/bin/setfacl -P --restore=-',
	   'uses physical restore with setfacl 2.4.0 and later');
	is(main::get_setfacl_restore_command('/usr/bin/setfacl'),
	   '/usr/bin/setfacl -P --restore=-',
	   'keeps using physical restore on later calls');
	is($calls, 1, 'caches the capability check');
};

subtest 'older setfacl remains supported' => sub {
	no warnings 'redefine';
	local *main::backquote_command = sub {
		return "setfacl 2.3.2 -- set file access control lists\n".
		       "Usage: setfacl [-bkndRLP] { -m|-M|-x|-X ... } file ...\n".
		       "  -P, --physical          physical walk, do not follow symbolic links\n".
		       "      --restore=file      restore ACLs (inverse of `getfacl -R')\n";
		};

	is(main::get_setfacl_restore_command('/usr/local/bin/setfacl'),
	   '/usr/local/bin/setfacl --restore=-',
	   'does not pass incompatible -P option to older versions');
};

done_testing();
