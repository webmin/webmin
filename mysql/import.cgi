#!/usr/local/bin/perl
# import.cgi
# Import data from a text file

require './mysql-lib.pl';
&ReadParseMime();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
$access{'edonly'} && &error($text{'dbase_ecannot'});
&error_setup($text{'import_err'});
$sql_charset = $in{'charset'};

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

# Build the import command
if ($in{'table'}) {
	$nfile = &transname("$in{'table'}.txt");
	&copy_source_dest($file, $nfile);
	unlink($file) if ($need_unlink);
	$file = $nfile;
	$need_unlink = 1;
	}
$delete = $in{'delete'} ? "-d" : "";
$ignore = $in{'ignore'} ? "-i" : "";
if ($in{'format'} == 0) {
	$format = "--fields-terminated-by , --fields-enclosed-by '\"'";
	}
elsif ($in{'format'} == 1) {
	$format = "--fields-terminated-by ,";
	}

# Execute the import command ..
print "<pre>";
&additional_log('exec', undef, "$config{'mysqlimport'} $authstr $delete $ignore $format $in{'db'} $file");
$cmd = "$config{'mysqlimport'} $authstr $delete $ignore $format ".quotemeta($in{'db'})." ".quotemeta($file);
if ($access{'buser'} && $access{'buser'} ne 'root' && $< == 0) {
	$cmd = &command_as_user($access{'buser'}, 0, $cmd);
	}
&open_execute_command(SQL, $cmd, 2, 0);
while(<SQL>) {
	print &html_escape($_);
	$got++ if (/\S/);
	}
close(SQL);
print "</pre>\n";
&webmin_log("import", undef, $in{'db'}, { 'mode' => $in{'mode'},
					  'file' => $in{'file'} });
unlink($file) if ($need_unlink);

&ui_print_footer("edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'});

