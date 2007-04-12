#!/usr/local/bin/perl
# save_export.cgi
# Create, update or delete an NFS export

require './sgiexports-lib.pl';
&ReadParse();
@exports = &get_exports();
$export = $exports[$in{'idx'}] if (!$in{'new'});

&lock_file($config{'exports_file'});
if ($in{'delete'}) {
	# Just delete this export
	&delete_export($export);
	}
else {
	# Validate and store inputs
	&error_setup($text{'save_err'});
	-d $in{'dir'} || &error($text{'save_edir'});
	$export->{'dir'} = $in{'dir'};
	$export->{'hosts'} = [ split(/\s+/, $in{'hosts'}) ];
	if ($in{'ro'}) { $export->{'opts'}->{'ro'} = ''; }
	else { delete($export->{'opts'}->{'ro'}); }
	if ($in{'wsync'}) { $export->{'opts'}->{'wsync'} = ''; }
	else { delete($export->{'opts'}->{'wsync'}); }
	if ($in{'anon_def'} == 1) { delete($export->{'opts'}->{'anon'}); }
	elsif ($in{'anon_def'} == 2) { $export->{'opts'}->{'anon'} = -1; }
	else {
		$in{'anon'} =~ /^-?[0-9]+$/ ||
			defined(getpwnam($in{'anon'})) ||
				&error($text{'save_eanon'});
		$export->{'opts'}->{'anon'} = $in{'anon'};
		}

	if ($in{'rw_def'}) {
		delete($export->{'opts'}->{'rw'});
		}
	else {
		@hosts = split(/\s+/, $in{'rw'});
		@hosts || &error($text{'save_erw'});
		$export->{'opts'}->{'rw'} = join(":", @hosts);
		}

	if ($in{'root_def'}) {
		delete($export->{'opts'}->{'root'});
		}
	else {
		@hosts = split(/\s+/, $in{'root'});
		@hosts || &error($text{'save_eroot'});
		$export->{'opts'}->{'root'} = join(":", @hosts);
		}

	if ($in{'access_def'}) {
		delete($export->{'opts'}->{'access'});
		}
	else {
		@hosts = split(/\s+/, $in{'access'});
		@hosts || &error($text{'save_eaccess'});
		$export->{'opts'}->{'access'} = join(":", @hosts);
		}

	if ($in{'new'}) {
		&create_export($export);
		}
	else {
		&modify_export($export);
		}
	}
&unlock_file($config{'exports_file'});
&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "modify",
	    "export", $export->{'dir'});
&redirect("");

