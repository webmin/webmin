#!/usr/local/bin/perl
# Delete multiple .htaccess files

require './htaccess-lib.pl';
&foreign_require($apachemod, "apache-lib.pl");
&ReadParse();
&error_setup($text{'delete_err'});
$can_create || &error($text{'dir_ecannotcreate'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

# Do the deletion of the .htaccess file and any user and group files
@dirs = &list_directories();
foreach $d (@d) {
	($dir) = grep { $_->[0] eq $d } @dirs;
	if ($dir) {
		$htaccess = "$dir->[0]/$config{'htaccess'}";
		&can_access_dir($htaccess) || &error($text{'dir_ecannot'});
		if ($in{'remove'}) {
			!$dir->[1] || &can_access_dir($dir->[1]) || &error($text{'dir_ecannotfile'});
			!$dir->[4] || &can_access_dir($dir->[4]) || &error($text{'dir_ecannotgfile'});
			# Block away the whole file
			&unlink_logged($htaccess);
			&unlink_logged($dir->[1])
				if (!-d $dir->[1]);
			&unlink_logged($dir->[4])
				if ($dir->[4] && !-d $dir->[4]);
			}
		else {
			# Take the authentication directives out of .htaccess
			$conf = &foreign_call($apachemod,
					      "get_htaccess_config", $htaccess);
			&foreign_call($apachemod, "save_directive",
				      "require", [ ], $conf, $conf);
			}
		@dirs = grep { $_ ne $dir } @dirs;
		}
	}
&flush_file_lines();

# Save directory list
&save_directories(\@dirs);
&webmin_log("delete", "dirs", scalar(@d));
&redirect("");

