#!/usr/local/bin/perl
# import.cgi
# Import data from a text file

require './postgresql-lib.pl';
&ReadParseMime();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
&error_setup($text{'import_err'});

if ($in{'mode'}) {
	# From uploaded file
	$in{'upload'} || &error($text{'import_eupload'});
	$in{'upload_filename'} =~ /([^\/\\\s]+)$/ ||
		&error($text{'import_eupload'});
	$file = &transname($1);
	open(TEMP, ">$file");
	print TEMP $in{'upload'};
	close(TEMP);
	$need_unlink = 1;
	&ui_print_header(undef, $text{'import_title'}, "");
	print "$text{'import_uploadout'}<p>\n";
	}
else {
	# From local file
	-r $in{'file'} || &error($text{'import_efile'});
	$file = $in{'file'};
	&ui_print_header(undef, $text{'import_title'}, "");
	print &text('import_fileout', "<tt>$in{'file'}</tt>"),"<p>\n";
	}

if (!$in{'delete'}) {
	$data = &execute_sql($in{'db'},
		"select * from ".&quote_table($in{'table'}));
	foreach $r (@{$data->{'data'}}) {
		$done{join("/", @$r)}++;
		}
	}

# Read the file
$skip = 0;
open(FILE, $file);
while(<FILE>) {
	s/\r|\n//g;
	next if (!/\S/);
	local @row;
	if ($in{'format'} == 0) {
		# Quoted and comma-separated
		s/\\\"/\0/g;
		while(/^,?"([^"]*)"(.*)/) {
			$field = $1;
			$_ = $2;
			$field =~ s/\0/"/g;
			push(@row, $field);
			}
		}
	elsif ($in{'format'} == 1) {
		# Just comma-separated
		s/\\,/\0/g;
		@row = split(/,/, $_);
		foreach my $r (@row) {
			$r =~ s/\0/,/g;
			}
		}
	elsif ($in{'format'} == 2) {
		# Tab separated
		@row = split(/\t/, $_);
		}
	if (!@row) {
		print &text('import_erow', "<tt>$_</tt>"),"<p>\n";
		goto failed;
		}
	if ($in{'ignore'} && $done{join("/", @row)}++) {
		# Skip duplicate
		$skip++;
		next;
		}
	push(@rv, \@row);
	}

# Empty the table, if requested
if ($in{'delete'}) {
	&execute_sql_logged($in{'db'}, "delete from ".
				       &quote_table($in{'table'}));
	}

# Add the rows
@str = &table_structure($in{'db'}, $in{'table'});
foreach $r (@rv) {
	@sets = map { "?" } @str;
	$cmd = "insert into ".&quote_table($in{'table'})." values (".
	       join(",", @sets).")";
	&execute_sql_logged($in{'db'}, $cmd, @$r);
	}
print &text('import_done', scalar(@rv), $skip),"<p>\n";

&webmin_log("import", undef, $in{'db'}, { 'mode' => $in{'mode'},
					  'file' => $in{'file'} });

failed:
unlink($file) if ($need_unlink);

&ui_print_footer("exec_form.cgi?db=$in{'db'}&mode=import", $text{'exec_return'},
		 "edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
		 "", $text{'index_return'});

