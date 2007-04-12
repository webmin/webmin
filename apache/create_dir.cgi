#!/usr/local/bin/perl
# create_dir.cgi
# Create an empty <Directory>, <Files> or <Location> clause

require './apache-lib.pl';
&ReadParse();
&error_setup($text{'cdir_err'});
($vconf, $v) = &get_virtual_config($in{'virt'});
&can_edit_virt($v) || &error($text{'virt_ecannot'});
$f = $vconf->[0]->{'file'};
for($j=0; $vconf->[$j]->{'file'} eq $f; $j++) { }
$l = $vconf->[$j-1]->{'eline'}+1;
&lock_file($f);
&before_changing();
$lref = &read_file_lines($f);
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
splice(@$lref, $l, 0, ($newdir, $enddir));
&flush_file_lines();
&unlock_file($f);
&after_changing();
&webmin_log("dir", "create", &virtual_name($v, 1).":$in{'path'}", \%in);
&redirect("virt_index.cgi?virt=$in{'virt'}");

