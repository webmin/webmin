#!/usr/local/bin/perl
# create_dir.cgi
# Create an empty <Directory>, <Files> or <Location> clause

require './apache-lib.pl';
&ReadParse();
&error_setup($text{'cdir_err'});
($vconf, $v) = &get_virtual_config($in{'virt'});
&can_edit_virt($v) || &error($text{'virt_ecannot'});

&lock_file($vconf->[0]->{'file'});
&before_changing();

# Validate inputs
$in{'path'} || &error($text{'cdir_epath'});
$in{'type'} eq 'Proxy' || $in{'type'} eq 'Location' ||
   &allowed_doc_dir($in{'path'}) || &error($text{'cdir_ecannot'});

# Create the file structure
$dir = { 'type' => 1 };
if ($in{'regexp'}) {
	$in{'type'} eq 'Proxy' && &error($text{'cdir_eproxy'});
	if ($httpd_modules{'core'} >= 1.3) {
		$dir->{'name'} = $in{'type'}."Match";
		$dir->{'value'} = "\"$in{'path'}\"";
		}
	else {
		$dir->{'name'} = $in{'type'};
		$dir->{'value'} = "~ \"$in{'path'}\"";
		}
	}
else {
	$dir->{'name'} = $in{'type'};
	$dir->{'value'} = "\"$in{'path'}\"";
	}

# Add to file
&save_directive_struct(undef, $dir, $vconf, $conf);
&flush_file_lines();
&update_last_config_change();
&unlock_file($vconf->[0]->{'file'});

&after_changing();
&format_config_file($vconf->[0]->{'file'});

&webmin_log("dir", "create", &virtual_name($v, 1).":$in{'path'}", \%in);
&redirect("virt_index.cgi?virt=$in{'virt'}");

