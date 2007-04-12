#!/usr/local/bin/perl
# create_dir.cgi
# Add a new <Directory> section to a virtual server

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
&error_setup($text{'dserv_err'});

# Validate inputs
$in{'dir'} =~ /^\S+$/ || &error($text{'dserv_edir'});
!$anon || $in{'dir'} !~ /^\// || $anon->{'value'} =~ /^\~/ ||
	&is_under_directory($anon->{'value'}, $in{'dir'}) ||
		&error($text{'dserv_eanondir'});

# Add the directory
$l = $conf->[@$conf - 1];
&lock_file($l->{'file'});
&before_changing();
$lref = &read_file_lines($l->{'file'});
@lines = ( "<Directory $in{'dir'}>", "</Directory>" );
splice(@$lref, $l->{'eline'}+1, 0, @lines);
&flush_file_lines();
&after_changing();
&unlock_file($l->{'file'});
&webmin_log("dir", "create", "$v->{'value'}:$in{'dir'}", \%in);
&redirect("dir_index.cgi?virt=$in{'virt'}&anon=$in{'anon'}&global=$in{'global'}&idx=".scalar(@$conf));

