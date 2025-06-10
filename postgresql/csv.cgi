#!/usr/local/bin/perl
# Export the CSV

require './postgresql-lib.pl';
&ReadParse();
&error_setup($text{'csv_err'});
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
$access{'edonly'} && &error($text{'dbase_ecannot'});

# Validate inputs
if ($in{'dest'}) {
	$in{'file'} =~ /^([a-z]:)?\/\S/ || &error($text{'csv_efile'});
	$access{'backup'} || &error($text{'cvs_ebuser'});
	}
if (!$in{'where_def'}) {
	$in{'where'} =~ /\S/ || &error($text{'csv_ewhere'});
	}

# Execute the SQL
@cols = split(/\0/, $in{'cols'});
@cols || &error($text{'csv_ecols'});
$cmd = "select ".join(",", @cols)." from ".&quote_table($in{'table'});
if (!$in{'where_def'}) {
	$cmd .= " where ".$in{'where'};
	}
$rv = &execute_sql($in{'db'}, $cmd);

# Open the destination
if (!$in{'dest'}) {
	print "Content-type: text/plain\n\n";
	$fh = STDOUT;
	}
else {
	# Open target file directly
	&open_tempfile(OUT, ">$in{'file'}");
	$fh = OUT;
	}

# Send the data
if ($in{'headers'}) {
	unshift(@{$rv->{'data'}}, $rv->{'titles'});
	}
foreach $r (@{$rv->{'data'}}) {
	if ($in{'format'} == 0) {
		print $fh join(",", map { "\"".&quote_csv($_, "\"\n")."\"" } @$r);
		}
	elsif ($in{'format'} == 1) {
		print $fh join(",", map { &quote_csv($_, ",\n") } @$r);
		}
	elsif ($in{'format'} == 2) {
		print $fh join("\t", map { &quote_csv($_, "\t\n") } @$r);
		}
	print $fh "\n";
	}

# All done .. tell the user
if ($in{'dest'}) {
	&close_tempfile(OUT);
	$desc = &text('table_header', "<tt>$in{'table'}</tt>", "<tt>$in{'db'}</tt>");
	&ui_print_header($desc, $text{'csv_title'}, "", "csv");

	@st = stat($in{'file'});
	print &text('csv_done', "<tt>$in{'file'}</tt>",
				&nice_size($st[7])),"<p>\n";

	&ui_print_footer("edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
		&get_databases_return_link($in{'db'}), $text{'index_return'});
	}

sub quote_csv
{
local ($str, $q) = @_;
$str =~ s/\r//g;
foreach my $c (split(//, $q)) {
	local $qc = $c eq "\"" ? "\\\"" :
		    $c eq "\n" ? "\\n" :
		    $c eq "," ? "\\," :
		    $c eq "\t" ? "\\t" : $c;
	$str =~ s/\Q$c\E/$qc/g;
	}
return $str;
}

