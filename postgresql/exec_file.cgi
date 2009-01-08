#!/usr/local/bin/perl
# exec_files.cgi
# Execute some SQL commands from a file and display the output

require './postgresql-lib.pl';
&ReadParseMime();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
&error_setup($text{'exec_err'});

if ($in{'mode'}) {
	# From uploaded file
	$in{'upload'} || &error($text{'exec_eupload'});
	$file = &transname();
	open(TEMP, ">$file");
	print TEMP $in{'upload'};
	close(TEMP);
	&ui_print_header(undef, $text{'exec_title'}, "");
	print "$text{'exec_uploadout'}<p>\n";
	}
else {
	# From local file
	-r $in{'file'} || &error($text{'exec_efile'});
	$file = $in{'file'};
	&ui_print_header(undef, $text{'exec_title'}, "");
	print &text('exec_fileout', "<tt>$in{'file'}</tt>"),"<p>\n";
	}

# Call the psql program on the file
print "<pre>";
($ex, $out) = &execute_sql_file($in{'db'}, $file);
print &html_escape($out);
$got++ if ($out =~ /\S/);
print "<i>$text{'exec_noout'}</i>\n" if (!$got);
print "</pre>\n";
&webmin_log("execfile", undef, $in{'db'}, { 'mode' => $in{'mode'},
					    'file' => $in{'file'} });
unlink($file) if ($in{'mode'});

&ui_print_footer("exec_form.cgi?db=$in{'db'}&mode=file", $text{'exec_return'},
		 "edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
		 "", $text{'index_return'});

