#!/usr/local/bin/perl
# delete_htaccess.cgi
# Delete some .htaccess or similar file

require './apache-lib.pl';
&ReadParse();
&allowed_auth_file($in{'file'}) ||
	&error($text{'htaccess_edelete'});
&lock_file($in{'file'});
unlink($in{'file'});
&unlock_file($in{'file'});

&read_file("$module_config_directory/site", \%site);
@ht = split(/\s+/, $site{'htaccess'});
$site{'htaccess'} = join(' ', (grep { $_ ne $in{'file'} } @ht));
&write_file("$module_config_directory/site", \%site);
&webmin_log("htaccess", "delete", $in{'file'});
&redirect("htaccess.cgi");

