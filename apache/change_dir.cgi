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
$lref = &read_file_lines($d->{'file'});

if ($in{'delete'}) {
	# deleting a directive
	$conf = &get_config();
	$gap = $d->{'eline'} - $d->{'line'} + 1;
	splice(@$lref, $d->{'line'}, $d->{'eline'} - $d->{'line'} + 1);
	splice(@$vconf, $in{'idx'}, 1);
	&renumber($conf, $d->{'line'}, $d->{'file'}, -$gap);
	}
else {
	# changing a directive
	&error_setup($text{'cdir_err2'});
	$in{'path'} || &error($text{'cdir_epath'});
	$in{'type'} eq 'Proxy' || &allowed_doc_dir($in{'path'}) ||
		&error($text{'cdir_ecannot'});
	if ($in{'regexp'}) {
		$in{'type'} eq 'Proxy' && &error($text{'cdir_eproxy'});
		if ($httpd_modules{'core'} >= 1.3) {
			$newdir = "<$in{'type'}Match \"$in{'path'}\">";
			$enddir = "</$in{'type'}Match>";
			}
		else {
			$newdir = "<$in{'type'} ~ \"$in{'path'}\">";
			$enddir = "</$in{'type'}>";
			}
		}
	else {
		$newdir = "<$in{'type'} \"$in{'path'}\">";
		$enddir = "</$in{'type'}>";
		}
	$lref->[$d->{'line'}] = $newdir;
	$lref->[$d->{'eline'}] = $enddir;
	}
&flush_file_lines();
&unlock_file($d->{'file'});
&after_changing();
&webmin_log("dir", $in{'delete'} ? 'delete' : 'save',
	    &virtual_name($v, 1).":".$d->{'words'}->[0], \%in);
&redirect("virt_index.cgi?virt=$in{'virt'}");

