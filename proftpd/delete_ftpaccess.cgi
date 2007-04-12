#!/usr/local/bin/perl
# delete_ftpaccess.cgi
# Delete some .ftpaccess or similar file

require './proftpd-lib.pl';
&ReadParse();
&lock_file($in{'file'});
unlink($in{'file'});
&unlock_file($in{'file'});

$site{'ftpaccess'} = join(' ', (grep { $_ ne $in{'file'} } @ftpaccess_files));
&write_file("$module_config_directory/site", \%site);
&webmin_log("ftpaccess", "delete", $in{'file'});
&redirect("ftpaccess.cgi");

