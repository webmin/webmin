#!/usr/bin/perl
# save_set.cgi
# Save a new or existing set

require './nftables-lib.pl';    ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
error_setup($text{'set_err'});
assert_acl('sets');

my @tables = get_nftables_save();
my $table = $tables[$in{'table'}];
$table || error($text{'set_notable'});
assert_table_acl($table);

my $is_new = $in{'new'} ? 1 : 0;
my $name = $in{'set_name'};
$name =~ /^\w[\w-]*$/ || error($text{'set_ename'});

if ($is_new && $table->{'sets'}->{$name}) {
	error($text{'set_edup'});
	}

my $type = $in{'set_type'};
$type = undef if (defined($type) && $type =~ /^\s*$/);
error($text{'set_etype'}) if (!$type);

my $flags = $in{'set_flags'};
if (defined($flags) && $flags ne '') {
	my @vals = split(/\0/, $flags);
	@vals = grep { defined($_) && $_ ne '' } @vals;
	$flags = @vals ? join(" ", @vals) : undef;
	}
$flags = undef if (defined($flags) && $flags =~ /^\s*$/);

my $elements = parse_set_elements_input($in{'set_elements'});

my $set;
if ($is_new) {
	$set = {'name' => $name, 'raw_lines' => [ ]};
	}
else {
	my $orig = $in{'set'};
	$set = $table->{'sets'}->{$orig};
	$set || error($text{'set_noset'});
	$name = $orig;
	}

$set->{'name'} = $name;
$set->{'type'} = $type;
$set->{'flags'} = $flags;
$set->{'elements'} = $elements;
$set->{'raw_lines'} ||= [ ];

$table->{'sets'}->{$name} = $set;

my $set_err = validate_set_references($table);
error($set_err) if ($set_err);

my $err = save_table_configuration($table, @tables);
error(text('set_failed', $err)) if ($err);

webmin_log($is_new ? "create" : "save",
	"set", $name, {'table' => $table->{'name'}, 'family' => $table->{'family'}});
redirect("index.cgi?table=$in{'table'}&view=sets");
