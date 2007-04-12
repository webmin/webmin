#!/usr/local/bin/perl
# calamaris.cgi
# Run calamaris on the squid logfile(s)

require './squid-lib.pl';
$access{'calamaris'} || &error($text{'calamaris_ecannot'});
&ui_print_header(undef, $text{'calamaris_title'}, "");

# is calamaris installed?
if (!&has_command($config{'calamaris'})) {
	print &text('calamaris_eprog', "<tt>$config{'calamaris'}</tt>",
		  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

# Work out Calamaris version and args
if (`$config{'calamaris'} -V 2>&1` =~ /revision:\s+(\S+)/i) {
	$ver = $1;
	}
$args = $config{'cal_all'} ? " -a" : "";
if ($ver >= 2.5) {
	if ($config{'cal_fmt'} eq 'w') {
		$args .= " -F html";
		}
	else {
		$args .= " -F mail";
		}
	}
else {
	$args .= " -".$config{'cal_fmt'};
	}
$args .= " $config{'cal_extra'}";

# are there any logfiles to analyse?
$ld = $config{'log_dir'};
opendir(DIR, $ld);
while($f = readdir(DIR)) {
	local @st = stat("$ld/$f");
	if ($f =~ /^access.log.*gz$/) {
		push(@files, [ "gunzip -c $ld/$f |", $st[9] ]);
		}
	elsif ($f =~ /^access.log.*Z$/) {
		push(@files, [ "uncompress -c $ld/$f |", $st[9] ]);
		}
	elsif ($f =~ /^access.log/) {
		push(@files, [ "$ld/$f", $st[9] ]);
		}
	}
closedir(DIR);
if (!@files) {
	print &text('calamaris_elogs', "<tt>$ld</tt>",
		  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

# run calamaris, parsing newest files and records first
$temp = &transname();
open(CAL, "| $config{'calamaris'} $args >$temp 2>/dev/null");
if ($config{'cal_max'}) {
	# read only the last N lines
	print &text('calamaris_last', $config{'cal_max'}),"<p>\n";
	@files = sort { $b->[1] <=> $a->[1] } @files;
	$lnum = 0;
	foreach $f (@files) {
		$left = $config{'cal_max'} - $lnum;
		last if ($left <= 0);
		if ($f->[0] =~ /\|$/) {
			open(LOG, "$f->[0] tail -$left |");
			}
		else {
			open(LOG, "tail -$left $f->[0] |");
			}
		while(<LOG>) {
			print CAL $_;
			$lnum++;
			}
		close(LOG);
		}
	}
else {
	# read all the log files
	foreach $f (@files) {
		open(LOG, $f->[0]);
		while(read(LOG, $buf, 1024) > 0) {
			print CAL $buf;
			}
		close(LOG);
		}
	}
close(CAL);

# Put the calamaris output into a nice webmin like table.
$date = localtime(time());
print "<table border width=100%>\n";
print "<tr $tb> <td><b>",&text('calamaris_gen', $date),"</b></td> </tr>\n";
print "<tr $cb> <td>\n";

open(OUT, $temp);
if ($config{'cal_fmt'} eq 'm') {
	print "<pre>";
	while(<OUT>) {
		print &html_escape($_);
		}
	print "</pre>\n";
	}
else {
	while(<OUT>) {
		if (/<\s*\/head/i || /<\s*body/i) { $inbody = 1; }
		elsif (/<\s*\/body/i) { $inbody = 0; }
		elsif ($inbody) { print; }
		}
	}
close(OUT);
unlink($temp);

# Close it.
print "</td></tr></table><p>";

&ui_print_footer("", $text{'index_return'});

