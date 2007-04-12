#!/usr/local/bin/perl
# save_dserv.cgi
# Save limit section options

require './proftpd-lib.pl';
&error_setup($text{'lserv_err'});
&ReadParse();
if ($in{'file'}) {
	$conf = &get_ftpaccess_config($in{'file'});
	}
else {
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
	if ($in{'idx'} ne '') {
		$conf = $conf->[$in{'idx'}]->{'members'};
		}
	}
$l = $conf->[$in{'limit'}];
$ln = $l->{'value'};

if ($in{'delete'}) {
	# Delete the directory
	&lock_file($l->{'file'});
	&before_changing();
	$lref = &read_file_lines($l->{'file'});
	splice(@$lref, $l->{'line'}, $l->{'eline'} - $l->{'line'} + 1);
	&flush_file_lines();
	&after_changing();
	&unlock_file($l->{'file'});
	if ($in{'file'}) {
		&redirect("ftpaccess_index.cgi?file=$in{'file'}");
		}
	elsif ($in{'idx'} eq '') {
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
		&redirect("dir_index.cgi?virt=$in{'virt'}&idx=$in{'idx'}&anon=$in{'anon'}&global=$in{'global'}");
		}
	&webmin_log("limit", "delete", $l->{'value'});
	}
else {
	# Update the limit
	local @c = split(/\0/, $in{'cmd'});
	@c || &error($text{'lserv_ecmd'});
	&lock_file($l->{'file'});
	&before_changing();
	$lref = &read_file_lines($l->{'file'});
	$lref->[$l->{'line'}] = "<Limit ".join(" ", @c).">";
	&flush_file_lines();
	&after_changing();
	&unlock_file($l->{'file'});
	&redirect("limit_index.cgi?virt=$in{'virt'}&idx=$in{'idx'}&limit=$in{'limit'}&anon=$in{'anon'}&file=$in{'file'}&global=$in{'global'}");
	&webmin_log("limit", "save", $l->{'value'}, \%in);
	}


