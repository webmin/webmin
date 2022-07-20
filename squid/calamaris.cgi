#!/usr/local/bin/perl
# calamaris.cgi
# Run calamaris on the squid logfile(s)

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config, %gconfig, $module_name);
require './squid-lib.pl';
$access{'calamaris'} || &error($text{'calamaris_ecannot'});
&ui_print_header(undef, $text{'calamaris_title'}, "");

# is calamaris installed?
if (!&has_command($config{'calamaris'})) {
	print &text('calamaris_eprog', "<tt>$config{'calamaris'}</tt>",
		  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

# Work out Calamaris version and args
my $ver;
if (&backquote_command("$config{'calamaris'} -V 2>&1") =~
    /(revision:|Calamaris)\s+(\d\S+)/i) {
	$ver = $2;
	}
my $args = $config{'cal_all'} ? " -a" : "";
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
my $ld = $config{'log_dir'};
my $fh;
my @files;
opendir($fh, $ld);
while(my $f = readdir($fh)) {
	my @st = stat("$ld/$f");
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
closedir($fh);
if (!@files) {
	print &text('calamaris_elogs', "<tt>$ld</tt>",
		  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

# run calamaris, parsing newest files and records first
my $temp = &transname();
my $fh2;
open($fh2, "| $config{'calamaris'} $args >$temp 2>/dev/null");
if ($config{'cal_max'}) {
	# read only the last N lines
	print &text('calamaris_last', $config{'cal_max'}),"<p>\n";
	@files = sort { $b->[1] <=> $a->[1] } @files;
	my $lnum = 0;
	foreach my $f (@files) {
		my $left = $config{'cal_max'} - $lnum;
		last if ($left <= 0);
		my $fh3;
		if ($f->[0] =~ /\|$/) {
			open($fh3, "$f->[0] tail -$left |");
			}
		else {
			open($fh3, "tail -$left $f->[0] |");
			}
		while(<$fh3>) {
			print $fh2 $_;
			$lnum++;
			}
		close($fh3);
		}
	}
else {
	# read all the log files
	my $fh3;
	foreach my $f (@files) {
		open($fh3, "<$f->[0]");
		my $buf;
		my $bs = &get_buffer_size();
		while(read($fh3, $buf, $bs) > 0) {
			print $fh2 $buf;
			}
		close($fh3);
		}
	}
close($fh2);

# Put the calamaris output into a nice webmin like table.
my $date = &make_date(time());
print &ui_table_start(&text('calamaris_gen', $date), undef, 2);

# Get the output
my $fh4;
open($fh4, $temp);
my $html = "";
if ($config{'cal_fmt'} eq 'm') {
	$html = "<pre>";
	while(<$fh4>) {
		$html .= &html_escape($_);
		}
	$html = "</pre>";
	}
else {
	my $inbody = 0;
	while(<$fh4>) {
		if (/<\s*\/head/i || /<\s*body/i) { $inbody = 1; }
		elsif (/<\s*\/body/i) { $inbody = 0; }
		elsif ($inbody) { $html .= $_; }
		}
	}
close($fh4);
unlink($temp);

# Show it
print &ui_table_row(undef, $html, 2);
print &ui_table_end();

&ui_print_footer("", $text{'index_return'});

