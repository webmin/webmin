#!/usr/local/bin/perl
# save_dserv.cgi
# Save directory section options

require './proftpd-lib.pl';
&ReadParse();
if ($in{'global'}) {
	$conf = &get_config();
	$conf = &get_or_create_global($conf);
	}
else {
	($conf, $v) = &get_virtual_config($in{'virt'});
	}
if ($in{'anon'}) {
	$anon = &find_directive_struct("Anonymous", $conf);
	$conf = $anon->{'members'};
	}
$d = $conf->[$in{'idx'}];
&error_setup($text{'dserv_err'});

if ($in{'delete'}) {
	# Delete the directory
	&lock_file($d->{'file'});
	&before_changing();
	$lref = &read_file_lines($d->{'file'});
	splice(@$lref, $d->{'line'}, $d->{'eline'} - $d->{'line'} + 1);
	&flush_file_lines();
	&after_changing();
	&unlock_file($d->{'file'});
	&webmin_log("dir", "delete", "$v->{'value'}:$d->{'words'}->[0]");
	if ($in{'global'}) {
		&redirect("");
		}
	elsif ($in{'anon'}) {
		&redirect("anon_index.cgi?virt=$in{'virt'}");
		}
	else {
		&redirect("virt_index.cgi?virt=$in{'virt'}");
		}
	}
else {
	# Update the directory
	$in{'dir'} =~ /^\S+$/ || &error($text{'dserv_edir'});
	&lock_file($d->{'file'});
	&before_changing();
	$lref = &read_file_lines($d->{'file'});
	$lref->[$d->{'line'}] = "<Directory $in{'dir'}>";
	&flush_file_lines();
	&after_changing();
	&unlock_file($d->{'file'});
	&webmin_log("dir", "save", "$v->{'value'}:$d->{'words'}->[0]");
	&redirect("dir_index.cgi?virt=$in{'virt'}&idx=$in{'idx'}&anon=$in{'anon'}&global=$in{'global'}");
	}


