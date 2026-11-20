#!/usr/bin/perl
use strict;
use warnings;
no warnings qw(once redefine);
use FindBin;
use File::Temp qw(tempdir);
use Test::More;

use lib "$FindBin::Bin/..";
require "web-lib.pl";
require "$FindBin::Bin/../config-lib.pl";
require "$FindBin::Bin/test-lib.pl";

my $dir = tempdir(CLEANUP => 1);
my $file = "$dir/config.info";
write_text($file, "first=First section,11\na=List,2,x-X,y-Y\n".
	"hidden=Hidden,0\nsecond=Second section,11\nb=Text,0\n");
write_text("$file.fr", "first=Première section\na=Liste\n");
local @main::lang_order_list = ('en', 'fr');
local *main::load_language_auto = sub { 0 };
local *test_module::config_pre_load = sub {
	my ($info) = @_;
	delete($info->{'hidden'});
	};

my $fields = main::read_config_fields($file, 'test-module');
is_deeply($fields->{'order'}, [qw(first a second b)],
	'partial translations and hidden fields preserve section order');
is($fields->{'info'}->{'first'}, 'Première section,11',
	'a translated heading keeps its section type');

local %main::in = (a => "x\0y");
my %config = (a => 'x', b => 'untouched', hidden => 'keep');
my $saved = main::parse_config(\%config, $fields, 'test-module', undef, 'first');
is_deeply($saved, ['a'], 'only the visible field is saved');
is_deeply(\%config, { a => 'x,y', b => 'untouched', hidden => 'keep' },
	'the translated field retains its type and other values survive');

local *main::error = sub { die "invalid section\n" };
eval { main::parse_config(\%config, $fields, 'test-module', undef, 'missing'); };
like($@, qr/invalid section/, 'a stale section cannot submit the whole form');

# A module can declare options before its first heading. The section editor
# must keep those options reachable without changing full-form field order.
write_text("$dir/mixed", "early=Early,0\nfirst=First,11\na=A,0\n".
	"second=Second,11\nb=B,0\n");
my $full = main::read_config_fields("$dir/mixed", 'test-module');
is($full->{'order'}->[0], 'early', 'full-form field order is preserved');
my $grouped = main::read_config_fields("$dir/mixed", 'test-module', 1);
is_deeply($grouped->{'sections'}, [ [ 'first', 'First' ], [ 'second', 'Second' ] ],
	'leading fields keep both sections available for navigation and search');
local %main::in = (early => 'saved', a => 'one');
my %mixed = (b => 'two');
main::parse_config(\%mixed, $grouped, 'test-module', undef, 'first');
is_deeply(\%mixed, { early => 'saved', a => 'one', b => 'two' },
	'the first section saves leading fields and preserves the next section');

# Full forms can also contain headings, restricted fields and passwords the
# user chose to keep. None should be copied into personal preferences.
write_text("$dir/full", "group=Options,11\nchoice=Choose,2,x-X,y-Y\n".
	"password=Password,12\nlocked=Restricted,0\n");
my %values = (choice => 'x', password => 'existing', locked => 'keep');
local %main::in = (password_nochange => 1);
my $permitted = { group => 1, choice => 1, password => 1 };
is_deeply(main::parse_config(\%values, "$dir/full", undef, $permitted),
	['choice'], 'only editable values written by the form count as saved');
is_deeply(\%values, { choice => undef, password => 'existing', locked => 'keep' },
	'clearing all choices preserves the password and restricted field');

# A custom callback can replace the whole hash and delete a personal override
# that has no system value. Both operations must reach the preference file.
{
	my %custom = ( keep => 'default', remove => 'old' );
	local *test_module::config_save = sub {
		my ($config) = @_;
		delete($config->{'personal'});
		%$config = ( keep => $config->{'keep'} );
		};
	my $written = main::parse_custom_config(\%custom, $file, 'test-module');
	is_deeply([ sort @$written ], [qw(keep personal remove)],
		'a custom save records resets and deletions');
	is_deeply(\%custom, { keep => 'default' }, 'the callback updates the config');
}

# A Usermin request must stop before any Webmin module code is loaded.
{
	local *main::get_product_name = sub { 'usermin' };
	local $main::text{'config_ecannot'} = 'Webmin only';
	local *main::error = sub { die "$_[0]\n" };
	eval { main::module_config_editor('test-module'); };
	like($@, qr/Webmin only/, 'global module configuration requires Webmin');
}
done_testing();
