#!/usr/local/bin/perl
# import.cgi
# Import data from a text file

use Fcntl qw(O_WRONLY O_CREAT O_EXCL);
require './mysql-lib.pl';
&ReadParseMime();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
$access{'edonly'} && &error($text{'dbase_ecannot'});
&error_setup($text{'import_err'});
$sql_charset = $in{'charset'};

# Use server-visible storage, not a /tmp hidden by the database service.
# If the server's directories are not on this host, keep the usual temp path.
my $import_tmpdir;
if ($< == 0 && &supports_users() && &is_mysql_local()) {
	$import_tmpdir = &mysql_import_tempdir($in{'db'});
	}

if ($in{'mode'}) {
	# From uploaded file
	$in{'upload'} || &error($text{'import_eupload'});
	$in{'upload_filename'} =~ /([^\/\\\s]+)$/ ||
		&error($text{'import_eupload'});
	$file = &mysql_import_tempname($import_tmpdir, $1);
	# Create a new upload file. Keep it owner-only when the server will be
	# granted access below; otherwise the umask applies as before.
	sysopen(TEMP, $file, O_WRONLY | O_CREAT | O_EXCL,
		$import_tmpdir ? 0600 : 0666) ||
		&error(&text('efileopen', &html_escape($file), &html_escape("$!")));
	print TEMP $in{'upload'};
	close(TEMP);
	&set_mysql_command_file_permissions($file) ||
		&error($text{'import_efile'});
	$need_unlink = 1;
	&ui_print_header(undef, $text{'import_title'}, "");
	print "$text{'import_uploadout'}<p>\n";
	}
else {
	# From local file
	$file = &mysql_import_tempname($import_tmpdir);
	&copy_file_under_global_acl($in{'file'}, $file, undef,
				     &mysql_command_unix_user()) ||
		&error($text{'import_efile'});
	$need_unlink = 1;
	&ui_print_header(undef, $text{'import_title'}, "");
	print &text('import_fileout', "<tt>".&html_escape($in{'file'})."</tt>"),"<p>\n";
	}

# Build the import command
if ($in{'table'}) {
	$nfile = &mysql_import_tempname($import_tmpdir, "$in{'table'}.txt");
	&copy_source_dest($file, $nfile);
	&set_mysql_command_file_permissions($nfile) ||
		&error($text{'import_efile'});
	unlink($file) if ($need_unlink);
	$file = $nfile;
	$need_unlink = 1;
	}
# A server-side import needs the local database server to read the file
if ($< == 0 && &supports_users() && &is_mysql_local()) {
	&set_mysql_import_file_permissions($in{'db'}, $file) ||
		&error($text{'import_eperms'});
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

&ui_print_footer("edit_dbase.cgi?db=".&urlize($in{'db'}), $text{'dbase_return'});

