#!/usr/local/bin/perl
# manual_save.cgi
# Save manually entered directives

require './proftpd-lib.pl';
&ReadParseMime();
if ($in{'global'}) {
	$conf = &get_config();
	$global = &find_directive_struct("Global", $conf);
	$conf = $global->{'members'};
	if (defined($in{'limit'})) {
		# limit within the global section
		if ($in{'idx'}) {
			$d = $conf->[$in{'idx'}];
			$l = $d->{'members'}->[$in{'limit'}];
			}
		else {
			$l = $conf->[$in{'limit'}];
			}
		$file = $l->{'file'};
		$return = "limit_index.cgi";
		$start = $l->{'line'}+1; $end = $l->{'eline'}-1;
		}
	else {
		# directory in the global section
		$d = $conf->[$in{'idx'}];
		$file = $d->{'file'};
		$return = "dir_index.cgi";
		$start = $d->{'line'}+1; $end = $d->{'eline'}-1;
		$logtype = 'dir';
		$logname = $d->{'value'};
		}
	}
elsif (defined($in{'virt'})) {
	if (defined($in{'limit'})) {
		# limit, maybe within a directory
		($conf, $v) = &get_virtual_config($in{'virt'});
		if ($in{'anon'}) {
			$anon = &find_directive_struct("Anonymous", $conf);
			$conf = $anon->{'members'};
			}
		if ($in{'idx'} ne '') {
			$conf = $conf->[$in{'idx'}]->{'members'};
			}
		$l = $conf->[$in{'limit'}];
		$file = $l->{'file'};
		$return = "limit_index.cgi";
		$start = $l->{'line'}+1; $end = $l->{'eline'}-1;
		$logtype = 'limit';
		$logname = $l->{'value'};
		}
	elsif (defined($in{'idx'})) {
		# directory within virtual server
		($vconf, $v) = &get_virtual_config($in{'virt'});
		if ($in{'anon'}) {
			$anon = &find_directive_struct("Anonymous", $vconf);
			$vconf = $anon->{'members'};
			}
		$d = $vconf->[$in{'idx'}];
		$file = $d->{'file'};
		$return = "dir_index.cgi";
		$start = $d->{'line'}+1; $end = $d->{'eline'}-1;
		$logtype = 'dir';
		$logname = "$v->{'value'}:$d->{'words'}->[0]";
		}
	else {
		# virtual server
		($conf, $v) = &get_virtual_config($in{'virt'});
		$return = "virt_index.cgi";
		$file = $v->{'file'};
		$start = $v->{'line'}+1; $end = $v->{'eline'}-1;
		$logtype = 'virt'; $logname = $v->{'words'}->[0];
		}
	}
else {
	if (defined($in{'limit'})) {
		# files within .htaccess file
		$hconf = &get_ftpaccess_config($in{'file'});
		$l = $hconf->[$in{'limit'}];
		$file = $in{'file'};
		$return = "limit_index.cgi";
		$start = $l->{'line'}+1; $end = $l->{'eline'}-1;
		$logtype = 'limit';
		$logname = $l->{'value'};
		}
	else {
		# .htaccess file
		$file = $in{'file'};
		$return = "ftpaccess_index.cgi";
		$logtype = 'ftpaccess'; $logname = $in{'file'};
		}
	}

&lock_file($file);
&lock_file($file);
$temp = &transname();
system("cp ".quotemeta($file)." $temp");
$in{'directives'} =~ s/\r//g;
$in{'directives'} =~ s/\s+$//;
@dirs = split(/\n/, $in{'directives'});
$lref = &read_file_lines($file);
if (!defined($start)) {
	$start = 0;
	$end = @$lref - 1;
	}
splice(@$lref, $start, $end-$start+1, @dirs);
&flush_file_lines();
if ($config{'test_manual'}) {
	$err = &test_config();
	if ($err) {
		system("mv $temp ".quotemeta($file));
		&error(&text('manual_etest', "<pre>$err</pre>"));
		}
	}
unlink($temp);
&unlock_file($file);
&webmin_log($logtype, "manual", $logname, \%in);

foreach $h ('virt', 'idx', 'file', 'limit', 'anon', 'global') {
	push(@args, "$h=$in{$h}") if (defined($in{$h}));
	}
&redirect("$return?".join("&", @args));

