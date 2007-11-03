#!/usr/local/bin/perl
# change_files.cgi
# Modify or delete a <Files> clause in a .htaccess file

require './apache-lib.pl';
&ReadParse();
$access{'global'} || &error($text{'htaccess_ecannot'});
&allowed_auth_file($in{'file'}) ||
	&error($text{'htindex_ecannot'});
$hconf = &get_htaccess_config($in{'file'});
$d = $hconf->[$in{'idx'}];
&lock_file($d->{'file'});
&before_changing();

if ($in{'delete'}) {
	# deleting a directive
	&save_directive_struct($d, undef, $hconf, $hconf);
	}
else {
	# changing a directive
	if ($in{'regexp'}) {
		if ($httpd_modules{'core'} >= 1.3) {
			$d->{'name'} = 'FilesMatch';
			$d->{'value'} = "\"$in{'path'}\"";
			}
		else {
			$d->{'name'} = 'Files';
			$d->{'value'} = "~ \"$in{'path'}\"";
			}
		}
	else {
		$d->{'name'} = 'Files';
		$d->{'value'} = "\"$in{'path'}\"";
		}
	&save_directive_struct($d, $d, $hconf, $hconf, 1);
	}
&flush_file_lines();
&unlock_file($d->{'file'});
&after_changing();

&webmin_log("files", $in{'delete'} ? 'delete' : 'save',
	    "$in{'file'}:$d->{'words'}->[0]", \%in);
&redirect("htaccess_index.cgi?file=".&urlize($in{'file'}));

