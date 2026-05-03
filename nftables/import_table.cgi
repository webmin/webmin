#!/usr/bin/perl
# import_table.cgi
# Import an active nftables table as a Webmin-managed saved table

require './nftables-lib.pl';    ## no critic
use strict;
use warnings;
use Storable qw(dclone);
our (%in, %text);
ReadParse();
error_setup($text{'import_err'});
assert_acl('import');

my ($active, $active_err) = get_active_nftables_save();
error(text('active_failed', $active_err)) if ($active_err);

my $source;
foreach my $t (@$active) {
	if ($t->{'family'} eq $in{'family'} && $t->{'name'} eq $in{'name'}) {
		$source = $t;
		last;
		}
	}
$source || error($text{'import_esource'});
assert_table_acl($source);

my @tables = get_nftables_save();
if (table_is_webmin_managed($source, \@tables)) {
	error(text('import_emanaged', nft_table_spec($source)));
	}

if ($in{'import'}) {
	my $name = $in{'new_name'};
	$name =~ /^\w[\w-]*$/ || error($text{'create_ename'});
	foreach my $t (@tables) {
		if ($t->{'family'} eq $source->{'family'} && $t->{'name'} eq $name) {
			error($text{'create_edup'});
			}
		}
	foreach my $t (@$active) {
		if ($t->{'family'} eq $source->{'family'} &&
			$t->{'name'} eq $name &&
			table_is_externally_managed($t))
		{
			error(text('import_eexternal', nft_table_spec($t)));
			}
		}

	my $import = dclone($source);
	$import->{'name'} = $name;
	delete($import->{'flags'});
	assert_table_acl($import);
	push(@tables, $import);
	write_configuration(@tables);
	register_managed_table(
		$import,
		'source' => 'imported',
		'imported_from' => nft_table_spec($source),
		'imported_from_family' => $source->{'family'},
		'imported_from_name' => $source->{'name'},
		'imported_at' => time()
	);
	webmin_log("import", "table", $source->{'name'},
		{'family' => $source->{'family'}, 'new' => $name});
	redirect("index.cgi?table_family=".
		    urlize($source->{'family'}).
		    "&table_name=".
		    urlize($name));
	return;
	}

ui_print_header(undef, $text{'import_title'}, "");

print ui_form_start("import_table.cgi");
print ui_hidden("family", $source->{'family'});
print ui_hidden("name", $source->{'name'});
print ui_hidden("import", 1);

print ui_table_start($text{'import_header'}, "width=100%", 2);
print ui_table_row($text{'import_source'}, html_escape(nft_table_spec($source)));
print ui_table_row($text{'import_flags'}, html_escape($source->{'flags'} || "-"));
print ui_table_row(
	$text{'import_new_name'},
	ui_textbox(
		"new_name", unique_import_table_name($source, \@tables, $active), 30
	)
);

if (table_is_externally_managed($source)) {
	print ui_table_row("", ui_note($text{'import_external_note'}),
		undef, undef, undef, 1);
	}
print ui_table_end();

print ui_form_end([[undef, $text{'import_ok'}]]);
ui_print_footer("active.cgi", $text{'active_return'});

# unique_import_table_name(&source-table, &saved-tables, &active-tables)
# Returns an unused table name for an imported active table
sub unique_import_table_name
{
my ($source, $saved, $active_tables) = @_;
my $base = "imported_".$source->{'name'};
$base =~ s/[^\w-]/_/g;
$base = "imported_table" if ($base !~ /^\w/);

my %used;
foreach my $list ($saved, $active_tables) {
	foreach my $t (@$list) {
		next if ($t->{'family'} ne $source->{'family'});
		$used{$t->{'name'}} = 1;
		}
	}
my $name = $base;
my $i = 1;
while ($used{$name}) {
	$name = $base."_".$i++;
	}
return $name;
}
