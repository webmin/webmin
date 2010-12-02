#!/usr/local/bin/perl
# restore.cgi
# Restore a database from a local file, or from an uploaded file

require './postgresql-lib.pl' ;
&ReadParseMime();

&error_setup ( $text{'restore_err'} ) ;
$access{'restore'} || &error($text{'restore_ecannot'});
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});

# Work out where to restore from
if ($in{'src'} == 0) {
	-r $in{'path'} || &error(&text('restore_pe2', $in{'path'}));
	$path = $in{'path'};
	$need_unlink = 0;
	}
else {
	$in{'data'} || &error($text{'restore_edata'});
	$path = &transname();
	&open_tempfile(DATA, ">$path");
	&print_tempfile(DATA, $in{'data'});
	&close_tempfile(DATA);
	}

# Validate tables list
if ($in{'tables_def'}) {
	$tables = undef;
	}
else {
	$in{'tables'} =~ /\S/ || &error($text{'restore_etables'});
	$tables = [ split(/\s+/, $in{'tables'}) ];
	}

# Validate database
&indexof($in{'db'}, &list_databases()) >= 0 ||
	&error(&text('restore_edb'));

$err = &restore_database($in{'db'}, $path, $in{'only'}, $in{'clean'}, $tables);
if ($err) {
	&error(&text('restore_failed', "<pre>$err</pre>"));
	}
else {
	&redirect ("edit_dbase.cgi?db=$in{'db'}") ;
	}

