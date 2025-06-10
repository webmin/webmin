#!/usr/local/bin/perl
# manual_save.cgi
# Save manually entered directives

require './apache-lib.pl';
&ReadParseMime();
$access{'types'} eq '*' || &error($text{'manual_ecannot'});
if (defined($in{'virt'})) {
	if (defined($in{'idx'})) {
		# directory within virtual server
		($vconf, $v) = &get_virtual_config($in{'virt'});
		$d = $vconf->[$in{'idx'}];
		$file = $d->{'file'};
		$return = "dir_index.cgi";
		$start = $d->{'line'}+1; $end = $d->{'eline'}-1;
		$logtype = 'dir';
		$logname = &virtual_name($v, 1).":".$d->{'words'}->[0];
		}
	else {
		# virtual server (which can have multiple files!)
		($conf, $v) = &get_virtual_config($in{'virt'});
		@files = &unique((map { $_->{'file'} } @$conf), $v->{'file'});
		$return = "virt_index.cgi";
		$file = $in{'editfile'} || $v->{'file'};
		&indexof($file, @files) >= 0 ||
			&error($text{'manual_efile'});
		if ($file eq $v->{'file'}) {
			$start = $v->{'line'}+1; $end = $v->{'eline'}-1;
			}
		else {
			$start = $end = undef;
			}
		$logtype = 'virt'; $logname = &virtual_name($v, 1);
		}
	}
else {
	if (defined($in{'idx'})) {
		# files within .htaccess file
		$hconf = &get_htaccess_config($in{'file'});
		$d = $hconf->[$in{'idx'}];
		$file = $in{'file'};
		$return = "files_index.cgi";
		$start = $d->{'line'}+1; $end = $d->{'eline'}-1;
		$logtype = 'files';
		$logname = "$in{'file'}:$d->{'words'}->[0]";
		}
	else {
		# .htaccess file
		$file = $in{'file'};
		$return = "htaccess_index.cgi";
		$logtype = 'htaccess'; $logname = $in{'file'};
		}
	}

&lock_file($file);
$temp = &transname();
&copy_source_dest($file, $temp);
$in{'directives'} =~ s/\r//g;
$in{'directives'} =~ s/\s+$//;
@dirs = split(/\n/, $in{'directives'});
$lref = &read_file_lines($file);
if (!defined($start)) {
	$start = 0;
	$end = @$lref - 1;
	}
splice(@$lref, $start, $end-$start+1, @dirs);
&format_config($lref);
&flush_file_lines();
if ($config{'test_manual'}) {
	$err = &test_config();
	if ($err) {
		&copy_source_dest($temp, $file);
		&error(&text('manual_etest',
			     "<pre>".&html_escape($err)."</pre>"));
		}
	}
unlink($temp);
&unlock_file($file);
&update_last_config_change();
&webmin_log($logtype, "manual", $logname, \%in);

foreach $h ('virt', 'idx', 'file') {
	push(@args, "$h=$in{$h}") if (defined($in{$h}));
	}
&redirect("$return?".join("&", @args));

