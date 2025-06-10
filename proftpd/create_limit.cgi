#!/usr/local/bin/perl
# create_limit.cgi
# Create a new <Limit> section

require './proftpd-lib.pl';
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
&error_setup($text{'lserv_err'});

# Validate inputs
$in{'cmd'} =~ /\S/ || &error($text{'lserv_ecmd'});

# Add the limit
$l = $conf->[@$conf - 1];
&lock_file($l->{'file'});
&before_changing();
$lref = &read_file_lines($l->{'file'});
@lines = ( "<Limit $in{'cmd'}>", "</Limit>" );
splice(@$lref, $l->{'eline'}+1, 0, @lines);
&flush_file_lines();
&after_changing();
&unlock_file($l->{'file'});
&webmin_log("limit", "create", $in{'cmd'}, \%in);
if ($in{'file'}) {
	&redirect("limit_index.cgi?file=$in{'file'}&limit=".scalar(@$conf));
	}
else {
	&redirect("limit_index.cgi?virt=$in{'virt'}&idx=$in{'idx'}&anon=$in{'anon'}&global=$in{'global'}&limit=".scalar(@$conf));
	}

