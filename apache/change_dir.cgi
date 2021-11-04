#!/usr/local/bin/perl
# change_dir.cgi
# Modify or delete a <Directory>, <Files> or <Location> clause

require './apache-lib.pl';
&ReadParse();
($vconf, $v) = &get_virtual_config($in{'virt'});
&can_edit_virt($v) || &error($text{'virt_ecannot'});
$d = $vconf->[$in{'idx'}];
&lock_file($d->{'file'});
&before_changing();
$conf = &get_config();

if ($in{'delete'}) {
	# deleting a directive
	&save_directive_struct($d, undef, $vconf, $conf);
	}
else {
	# changing a directive
	&error_setup($text{'cdir_err2'});
	$in{'path'} || &error($text{'cdir_epath'});
	$in{'type'} eq 'Proxy' || $in{'type'} eq 'Location' ||
	    &allowed_doc_dir($in{'path'}) ||
		&error($text{'cdir_ecannot'});
	if ($in{'regexp'}) {
		$in{'type'} eq 'Proxy' && &error($text{'cdir_eproxy'});
		if ($httpd_modules{'core'} >= 1.3) {
			$d->{'name'} = $in{'type'}."Match";
			$d->{'value'} = "\"$in{'path'}\"";
			}
		else {
			$d->{'name'} = $in{'type'};
			$d->{'value'} = "~ \"$in{'path'}\"";
			}
		}
	else {
		$d->{'name'} = $in{'type'};
		$d->{'value'} = "\"$in{'path'}\"";
		}
	&save_directive_struct($d, $d, $vconf, $conf, 1);
	}
&flush_file_lines();
&unlock_file($d->{'file'});
&update_last_config_change();

&after_changing();
&format_config_file($d->{'file'});

&webmin_log("dir", $in{'delete'} ? 'delete' : 'save',
	    &virtual_name($v, 1).":".$d->{'words'}->[0], \%in);
&redirect("virt_index.cgi?virt=$in{'virt'}");

