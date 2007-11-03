#!/usr/local/bin/perl
# create_files.cgi
# Create an empty <Files> clause in a .htaccess file

require './apache-lib.pl';
$access{'global'} || &error($text{'htaccess_ecannot'});
&allowed_auth_file($in{'file'}) ||
	&error($text{'htindex_ecannot'});
&ReadParse();
$hconf = &get_htaccess_config($in{'file'});
&lock_file($in{'file'});
&before_changing();

# Create the directive
$dir = { 'type' => 1 };
if ($in{'regexp'}) {
	if ($httpd_modules{'core'} >= 1.3) {
		$dir->{'name'} = 'FilesMatch';
		$dir->{'value'} = "\"$in{'path'}\"";
		}
	else {
		$dir->{'name'} = 'Files';
		$dir->{'value'} = "~ \"$in{'path'}\"";
		}
	}
else {
	$dir->{'name'} = 'Files';
	$dir->{'value'} = "\"$in{'path'}\"";
	}

# Add to file
&save_directive_struct(undef, $dir, $hconf, $hconf);
&flush_file_lines();
&unlock_file($in{'file'});

&after_changing();
&webmin_log("files", "create", "$in{'file'}:$in{'path'}", \%in);
&redirect("htaccess_index.cgi?file=".&urlize($in{'file'}));

