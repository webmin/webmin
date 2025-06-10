#!/usr/local/bin/perl
# create_ftpaccess.cgi
# Creates a new .ftpaccess file for some directory

require './proftpd-lib.pl';
&ReadParse();
$conf = &get_config();

if (-d $in{'file'}) {
	# user entered a directory.. create a file in that directory
	$file = "$in{'file'}/.ftpaccess";
	}
else { $file = $in{'file'}; }

# create the file (if needed), and add to the known list
&lock_file($file);
if (!(-r $file)) {
	&open_lock_tempfile(FTPACCESS, ">$file") || &error($!);
	&close_tempfile(FTPACCESS);
	chmod(0755, $file);
	}
$site{'ftpaccess'} = join(' ', &unique(@ftpaccess_files, $file));
&write_file("$module_config_directory/site", \%site);
&unlock_file($file);
&webmin_log("ftpaccess", "create", $file);

# redirect to editing index
&redirect("ftpaccess_index.cgi?file=".&urlize($file));

