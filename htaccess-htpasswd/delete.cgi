#!/usr/local/bin/perl
# Delete multiple .htaccess files

require './htaccess-lib.pl';
&foreign_require($apachemod, "apache-lib.pl");
&ReadParse();
&error_setup($text{'delete_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

# Do the deletion of the .htaccess file and any user and group files
@dirs = &list_directories();
foreach $d (@d) {
	($dir) = grep { $_->[0] eq $d } @dirs;
	if ($dir) {
		$htaccess = "$dir->[0]/$config{'htaccess'}";
		&can_access_dir($htaccess) || &error($text{'dir_ecannot'});
		&unlink_logged($htaccess);
		&unlink_logged($dir->[1]);
		&unlink_logged($dir->[4]) if ($dir->[4]);
		@dirs = grep { $_ ne $dir } @dirs;
		}
	}

# Save directory list
&save_directories(\@dirs);
&webmin_log("delete", "dirs", scalar(@d));
&redirect("");

