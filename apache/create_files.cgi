#!/usr/local/bin/perl
# create_files.cgi
# Create an empty <Files> clause in a .htaccess file

require './apache-lib.pl';
$access{'global'} || &error($text{'htaccess_ecannot'});
&allowed_auth_file($in{'file'}) ||
	&error($text{'htindex_ecannot'});
&ReadParse();
&lock_file($in{'file'});
&before_changing();
$lref = &read_file_lines($in{'file'});
if ($in{'regexp'}) {
	if ($httpd_modules{'core'} >= 1.3) {
		$newdir = "<FilesMatch \"$in{'path'}\">";
		$enddir = "</FilesMatch>";
		}
	else {
		$newdir = "<Files ~ \"$in{'path'}\">";
		$enddir = "</Files>";
		}
	}
else {
	$newdir = "<Files \"$in{'path'}\">";
	$enddir = "</Files>";
	}
push(@$lref, $newdir);
push(@$lref, $enddir);
&flush_file_lines();
&unlock_file($in{'file'});
&after_changing();
&webmin_log("files", "create", "$in{'file'}:$in{'path'}", \%in);
&redirect("htaccess_index.cgi?file=".&urlize($in{'file'}));

