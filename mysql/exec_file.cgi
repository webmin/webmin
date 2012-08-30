#!/usr/local/bin/perl
# exec_file.cgi
# Execute some SQL commands from a file and display the output

require './mysql-lib.pl';
&ReadParseMime();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
$access{'edonly'} && &error($text{'dbase_ecannot'});
&error_setup($text{'exec_err'});
$sql_charset = $in{'charset'};

if ($in{'mode'}) {
	# From uploaded file
	$in{'upload'} || &error($text{'exec_eupload'});
	$file = &transname();
	open(TEMP, ">$file");
	print TEMP $in{'upload'};
	close(TEMP);
	&ui_print_header(undef, $text{'exec_title'}, "");
	print "$text{'exec_uploadout'}<p>\n";
	$need_unlink = 1;
	}
else {
	# From local file
	-r $in{'file'} || &error($text{'exec_efile'});
	$file = $in{'file'};
	&ui_print_header(undef, $text{'exec_title'}, "");
	print &text('exec_fileout', "<tt>$in{'file'}</tt>"),"<p>\n";
	$need_unlink = 0;
	}

# Un-compress file if needed
$cf = &compression_format($file);
$cmd = $cf == 1 ? "gunzip -c" :
       $cf == 2 ? "uncompress -C" :
       $cf == 3 ? "bunzip2 -c" : undef;
if ($cmd) {
	($prog, @args) = split(/\s+/, $cmd);
	&has_command($prog) ||
		&error(&text('exec_ecompress', "<tt>$prog</tt>"));
	$tempfile = &transname();
	$out = &backquote_command("$cmd <$file 2>&1 >$tempfile");
	if ($?) {
		&error(&text('exec_ecompress2', "<pre>$out</pre>"));
		}
	unlink($file) if ($need_unlink);
	$file = $tempfile;
	$need_unlink = 1;
	}

# Check the file for tables created and rows inserted
$create_count = 0;
$insert_count = 0;
open(SQL, $file);
while(<SQL>) {
	if (/^\s*insert\s+into\s+`(\S+)`/i ||
            /^\s*insert\s+into\s+(\S+)/i) {
		$insert_count++;
		}
	if (/^\s*create\s+table\s+`(\S+)`/i ||
            /^\s*create\s+table\s+(\S+)/i) {
		$create_count++;
		}
	}
close(SQL);

print "<pre>";
($ex, $out) = &execute_sql_file($in{'db'}, $file,
				undef, undef, $access{'buser'});
print &html_escape($out);
$got++ if ($out =~ /\S/);
print "<i>$text{'exec_noout'}</i>\n" if (!$got);
print "</pre>\n";
if (!$ex) {
	if ($create_count) {
		print &text('exec_created', $create_count),"\n";
		}
	if ($insert_count) {
		print &text('exec_inserted', $insert_count),"\n";
		}
	if ($create_count || $insert_count) {
		print "<p>\n";
		}
	}
&webmin_log("execfile", undef, $in{'db'}, { 'mode' => $in{'mode'},
					    'file' => $in{'file'} });
unlink($file) if ($need_unlink);

&ui_print_footer("exec_form.cgi?db=$in{'db'}&mode=file", $text{'exec_return'},
	"edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
	&get_databases_return_link($in{'db'}), $text{'index_return'});

