#!/usr/local/bin/perl
# manual.cgi
# Display a text box for manually editing directives

require './proftpd-lib.pl';
&ReadParse();
if ($in{'global'}) {
	$conf = &get_config();
	$global = &find_directive_struct("Global", $conf);
	$conf = $global->{'members'};
	if (defined($in{'limit'})) {
		# limit within the global section
		if ($in{'idx'}) {
			$d = $conf->[$in{'idx'}];
			$l = $d->{'members'}->[$in{'limit'}];
			$title = &text('limit_header4', $l->{'value'},
				       $d->{'words'}->[0]);
			}
		else {
			$l = $conf->[$in{'limit'}];
			$title = &text('limit_header7', $l->{'value'});
			}
		$return = "limit_index.cgi"; $rmsg = $text{'limit_return'};
		$file = $l->{'file'};
		$start = $l->{'line'}+1; $end = $l->{'eline'}-1;
		}
	else {
		# directory in the global section
		$d = $conf->[$in{'idx'}];
		$title = &text('dir_header5', $d->{'words'}->[0]);
		$return = "dir_index.cgi"; $rmsg = $text{'dir_return'};
		$file = $d->{'file'};
		$start = $d->{'line'}+1; $end = $d->{'eline'}-1;
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
			$dir = $conf->[$in{'idx'}];
			$conf = $dir->{'members'};
			}
		$l = $conf->[$in{'limit'}];
		$ln = $l->{'value'};
		$title = $dir ?
			&text('limit_header4', $ln, $dir->{'words'}->[0]) :
			$in{'virt'} ?
			&text('limit_header1', $ln, $v->{'words'}->[0]) :
			&text('limit_header2', $ln);
		$return = "limit_index.cgi"; $rmsg = $text{'limit_return'};
		$file = $l->{'file'};
		$start = $l->{'line'}+1; $end = $l->{'eline'}-1;
		}
	elsif (defined($in{'idx'})) {
		# directory within virtual server
		($vconf, $v) = &get_virtual_config($in{'virt'});
		if ($in{'anon'}) {
			$anon = &find_directive_struct("Anonymous", $vconf);
			$vconf = $anon->{'members'};
			}
		$d = $vconf->[$in{'idx'}];
		$dn = $d->{'words'}->[0];
		$title = $in{'anon'} ? &text('dir_header4', $dn) : $in{'virt'} ?
			&text('dir_header1', $dn, $v->{'words'}->[0]) :
			&text('dir_header2', $dn);
		$return = "dir_index.cgi"; $rmsg = $text{'dir_return'};
		$file = $d->{'file'};
		$start = $d->{'line'}+1; $end = $d->{'eline'}-1;
		}
	else {
		# virtual server
		($conf, $v) = &get_virtual_config($in{'virt'});
		$title = $in{'virt'} eq '' ? $text{'virt_header2'} :
		         &text('virt_header1', $v->{'value'});
		$return = "virt_index.cgi"; $rmsg = $text{'virt_return'};
		$file = $v->{'file'};
		$start = $v->{'line'}+1; $end = $v->{'eline'}-1;
		}
	}
else {
	# Something in a .ftpaccess file
	if (defined($in{'limit'})) {
		# limit within .ftpaccess file
		$hconf = &get_ftpaccess_config($in{'file'});
		$l = $hconf->[$in{'limit'}];
		$file = $in{'file'};
		$start = $l->{'line'}+1; $end = $l->{'eline'}-1;
		$title = &text('limit_header6', $l->{'value'},
			       "<tt>$in{'file'}</tt>");
		$return = "limit_index.cgi";
		$rmsg = $text{'limit_return'};
		}
	else {
		# .ftpaccess file
		$file = $in{'file'};
		$title = &text('ftpindex_header', "<tt>$in{'file'}</tt>");
		$return = "ftpaccess_index.cgi";
		$rmsg = $text{'ftpindex_return'};
		}
	}
&ui_print_header($title, $text{'manual_title'}, "",
	undef, undef, undef, undef, &restart_button());

print &text('manual_header', "<tt>$file</tt>"),"<p>\n";
print "<form action=manual_save.cgi method=post enctype=multipart/form-data>\n";
foreach $h ('virt', 'idx', 'file', 'limit', 'anon', 'global') {
	if (defined($in{$h})) {
		print "<input type=hidden name=$h value='$in{$h}'>\n";
		push(@args, "$h=$in{$h}");
		}
	}
$args = join('&', @args);

print "<textarea rows=15 cols=80 name=directives>\n";
$lref = &read_file_lines($file);
if (!defined($start)) {
	$start = 0;
	$end = @$lref - 1;
	}
for($i=$start; $i<=$end; $i++) {
	print &html_escape($lref->[$i]),"\n";
	}
print "</textarea><br><input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("$return?$args", $rmsg);

