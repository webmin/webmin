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
$lref = &read_file_lines($d->{'file'});

if ($in{'delete'}) {
	# deleting a directive
	$gap = $d->{'eline'} - $d->{'line'} + 1;
	splice(@$lref, $d->{'line'}, $d->{'eline'} - $d->{'line'} + 1);
	splice(@$hconf, $in{'idx'}, 1);
	&renumber($hconf, $d->{'line'}, $d->{'file'}, -$gap);
	}
else {
	# changing a directive
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
	$lref->[$d->{'line'}] = $newdir;
	$lref->[$d->{'eline'}] = $enddir;
	}
&flush_file_lines();
&unlock_file($d->{'file'});
&after_changing();
&webmin_log("files", $in{'delete'} ? 'delete' : 'save',
	    "$in{'file'}:$d->{'words'}->[0]", \%in);
&redirect("htaccess_index.cgi?file=".&urlize($in{'file'}));

