#!/usr/local/bin/perl
# view_doc.cgi
# View some HOWTO doc file

require './man-lib.pl';
&ReadParse();

$in{'file'} !~ /\.\./ ||
	&error($text{'howto_epath'});
$in{'file'} !~ /[\\\&\;\`\'\"\|\*\?\~\<\>\^\(\)\[\]\{\}\$\n\r]/ ||
	&error($text{'howto_epath'});
foreach $h (split(/\s+/, $config{'howto_dir'})) {
	$ok++ if (substr($in{'file'}, 0, length($h)) eq $h);
	}
$ok || &error($text{'howto_epath'});
-r $in{'file'} || &error($text{'howto_epath'});

&ui_print_header(undef, $text{'howto_title'}, "");

print "<table border width=100%>\n";
print "<tr $tb> <td><b>",&text('howto_header', $in{'file'}),"</b></td> </tr>\n";
print "<tr $cb> <td><pre>";
open(FILE, $in{'file'});
read(FILE, $two, 2);
$qm = quotemeta($in{'file'});
if ($two eq "\037\213") {
	close(FILE);
	&open_execute_command(FILE, "gunzip -c $qm", 1, 1);
	}
elsif ($two eq "BZ") {
	close(FILE);
	&open_execute_command(FILE, "bunzip2 -c $qm", 1, 1);
	}
seek(FILE, 0, 0);
@for = split(/\s+/, $in{'for'});
while($line = <FILE>) {
	$line = &html_escape($line);
	foreach $f (@for) {
		$line =~ s/.\010//g;
		$line =~ s/($f)/<b>$1<\/b>/ig;
		}
	print $line;
	}
close(FILE);
print "</pre></td></tr></table><p>\n";

&ui_print_footer("", $text{'index_return'});

