#!/usr/bin/perl
# Save aliases through the real CGI and read them back from the aliases file.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use FindBin;
use File::Temp qw(tempdir);

my $root = "$FindBin::Bin/..";
require "$root/web-lib-funcs.pl";
require "$FindBin::Bin/test-lib.pl";
require "$root/sendmail/aliases-lib.pl";
my $tmp = tempdir(CLEANUP => 1);

# Load the table comment helpers without the module setup code
my $source = read_text("$root/sendmail/sendmail-lib.pl");
foreach my $name (qw(is_table_comment make_table_comment)) {
	$source =~ /(^sub \Q$name\E\n\{.*?^\}\n)/ms or die "Missing $name";
	eval 'no strict; no warnings; '.$1;
	die $@ if ($@);
	}

# Replace setup, logging and alias rebuilding
$INC{'./sendmail-lib.pl'} = $INC{'./aliases-lib.pl'} = 1;
*main::ReadParse = sub { };
*main::error = sub { die join(' ', @_)."\n" };
*main::get_sendmailcf = sub { return [ ] };
*main::rebuild_map_cmd = sub { return 1 };
*main::system_logged = sub { return 0 };
*main::webmin_log = sub { };
*main::redirect = sub { };
open(my $lang, '<', "$root/sendmail/lang/en") or die $!;
while (<$lang>) {
	$main::text{$1} = $2 if /^(\S+)=(.*)$/;
	}
close($lang);
$main::module_config_directory = "$tmp/config";
my $afile = "$tmp/aliases";
%main::config = ( 'alias_file' => $afile );

# save_alias(&inputs, [&access])
# Runs save_alias.cgi to create an alias, and returns the error if any
sub save_alias
{
my ($in, $acl) = @_;
local %main::in = ( 'new' => 1, 'enabled' => 1, %$in );
local %main::access = ( 'amode' => 1, 'apath' => '/',
			map { ("aedit_$_" => 1) } (1..6) );
%main::access = ( %main::access, %$acl ) if ($acl);
local (@main::values, %main::newa);
%main::list_aliases_cache = ( );
eval { do "$root/sendmail/save_alias.cgi"; die $@ if ($@); };
return $@;
}

# read_alias(name)
# Returns the destinations of an alias, as read back from the file
sub read_alias
{
my ($name) = @_;
%main::list_aliases_cache = ( );
my ($a) = grep { $_->{'name'} eq $name } main::list_aliases([ $afile ]);
return $a ? $a->{'values'} : undef;
}

write_text($afile, "");
is(save_alias({ 'name' => 'plain', 'type_0' => 1, 'val_0' => 'bob' }), '',
   'normal address saved');
is_deeply(read_alias('plain'), [ 'bob' ], 'address read back');

is(save_alias({ 'name' => 'plus', 'type_0' => 1,
		'val_0' => 'first.last+tag@example.com' }), '',
   'address with plus saved');
is_deeply(read_alias('plus'), [ 'first.last+tag@example.com' ],
	  'address with plus read back');

my %noprog = ( 'aedit_4' => 0 );
like(save_alias({ 'name' => 'evil', 'type_0' => 1,
		  'val_0' => 'bob,|/tmp/p' }, \%noprog),
     qr/would split it/, 'comma cannot add a program destination');
is(read_alias('evil'), undef, 'nothing written');

like(save_alias({ 'name' => 'evil2', 'type_0' => 3,
		  'val_0' => '/tmp/x,|/tmp/p' }, \%noprog),
     qr/would split it/, 'file destination cannot add a program either');

like(save_alias({ 'name' => 'x",|/tmp/p,"y', 'type_0' => 5,
		  'val_0' => '/tmp/reply' }, \%noprog),
     qr/would split it/, 'quote in the name cannot split an autoreply');

my $prog = -x '/bin/echo' ? '/bin/echo' : '/usr/bin/true';
is(save_alias({ 'name' => 'prog', 'type_0' => 4, 'val_0' => "$prog a,b" }),
   '', 'program with a comma in its arguments saved');
is_deeply(read_alias('prog'), [ "|$prog a,b" ], 'program read back whole');

done_testing();
