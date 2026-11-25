#!/usr/bin/perl
# Check Webmin action details across consecutive audit entries.
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use File::Basename qw(dirname);
use Cwd qw(abs_path);

my $root = abs_path(dirname(__FILE__).'/..');
require "$root/web-lib-funcs.pl";
require "$root/t/test-lib.pl";

# Load the real log reader without initializing a host Webmin installation.
{
    local $INC{'WebminCore.pm'} = 1;
    no warnings 'redefine';
    local *main::init_config = sub { };
    local *main::get_module_acl = sub { return (); };
    require "$root/webminlog/webminlog-lib.pl";
}

my $tmp = tempdir('webmin-audit-XXXXXX', DIR => '/tmp', CLEANUP => 1);
local $ENV{'WEBMIN_VAR'} = $tmp;
local $main::webmin_logfile = "$tmp/webmin.log";
local %main::gconfig = (log => 1, logfiles => 1);
local @main::locked_file_diff;
local $main::action_id_count = 0;
local $main::remote_user = 'fixture';
local $main::scriptname = 'fixture.cgi';

# Only host/module metadata is stubbed; serialization and parsing stay real.
no warnings 'redefine';
local *main::is_readonly_mode = sub { return 0; };
local *main::get_module_name = sub { return 'fixture'; };
local *main::get_module_variable = sub { return undef; };
local *main::get_module_info = sub { return (desc => 'Fixture'); };

# A submission with no details must leave no placeholder for completion.
main::webmin_log('submit', 'vm', 'fixture', {});
is(scalar(@main::locked_file_diff), 0, 'first action leaves an empty detail queue');
main::additional_log('exec', undef, 'libvirt API: fixture', 'safe input');
main::webmin_log('complete', 'vm', 'fixture', {});
is(scalar(@main::locked_file_diff), 0, 'completion clears all queued details');
main::webmin_log('another', 'vm', 'fixture', {});
my @lines = split(/\n/, read_text($main::webmin_logfile));
is(scalar(@lines), 3, 'all three action entries remain present');
my @actions = map { { id => (split(/\s+/, $_))[0] } } @lines;
is_deeply([main::list_diffs($actions[0])], [], 'submission has no details');
my @diffs = main::list_diffs($actions[1]);
is(scalar(@diffs), 1, 'completion has exactly one command detail');
is($diffs[0]->{'type'}, 'exec', 'the detail is the real command');
is($diffs[0]->{'diff'}, 'libvirt API: fixture', 'command data is preserved');
is($diffs[0]->{'input'}, 'safe input', 'command input remains attached');
is_deeply([main::list_diffs($actions[2])], [], 'later actions inherit no blank record');

# Existing empty records are ignored in both supported directory layouts.
for my $layout ('old', 'new') {
    my $id = '1700000000.123.'.($layout eq 'old' ? '0' : '1');
    my $base = $layout eq 'old' ? "$tmp/diffs/17000/$id" : "$tmp/diffs/$id";
    make_path($base);
    write_text("$base/0", " \n");
    write_text("$base/1", "");
    write_text("$base/2", "create /fixture/empty-file\n");
    write_text("$base/3", "exec \nreal command");
    my @records = main::list_diffs({id => $id});
    is_deeply([map { $_->{'type'} } @records], [qw(create exec)],
        "$layout layout skips invalid records but keeps empty file creation");
    is($records[-1]->{'diff'}, 'real command', "$layout layout preserves following details");
}
# Actions without a parser description remove markup from the logged name.
{
    local $main::parser_cache{'fixture'} = 0;
    my $action = { module => 'fixture', action => 'create', type => 'table',
                   object => q{<img src=x onerror=alert(1)>Sales&Co} };
    is(main::get_action_description($action), 'create table Sales&amp;Co',
        'fallback descriptions are sanitized');
}

# Read database audit records back from the log before rendering.
{
    local @INC = ($tmp, @INC);
    local *mysql::text = \&main::text;
    local *postgresql::text = \&main::text;
    write_text("$tmp/mysql-lib.pl", "1;\n");
    write_text("$tmp/postgresql-lib.pl", "1;\n");
    {
        package mysql;
        do "$root/mysql/log_parser.pl" or die $@ || $!;
    }
    {
        package postgresql;
        do "$root/postgresql/log_parser.pl" or die $@ || $!;
    }
    my $name = q{<img src=x onerror=alert(1)>Sales&Co};
    my $db = q{<svg/onload=alert(1)>Reports, "2026"};
    for my $module ('mysql', 'postgresql') {
        local $main::parser_cache{$module} = 1;
        local %main::text;
        main::read_file("$root/$module/lang/en", \%main::text);
        main::webmin_log('create', 'table', $name, { db => $db }, $module);
        my @lines = split(/\n/, read_text($main::webmin_logfile));
        my $action = main::parse_logline($lines[-1]);
        is(main::get_action_description($action),
            'Created table <tt>Sales&amp;Co</tt> in database <tt>Reports, &quot;2026&quot;</tt>',
            "$module keeps formatting but removes markup from names");
    }
}
done_testing();
