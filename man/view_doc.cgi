#!/usr/local/bin/perl
# view_doc.cgi
# View some package doc file

require './man-lib.pl';
&ReadParse();

$in{'file'} !~ /\.\./ ||
	&error($text{'doc_epath'});
$in{'file'} !~ /[\\\&\;\`\'\"\|\*\?\~\<\>\^\(\)\[\]\{\}\$\n\r]/ ||
	&error($text{'doc_epath'});
foreach $d (split(/\s+/, $config{'doc_dir'})) {
	$ok++ if (substr($in{'file'}, 0, length($d)) eq $d);
	}
$ok++ if ($config{'custom_dir'} && substr($in{'file'}, 0,
		length($config{'custom_dir'})) eq $config{'custom_dir'});
$ok || &error($text{'doc_epath'});
if (!-r $in{'file'}) {
	if (-r "$in{'file'}.gz") {
		$in{'file'} = "$in{'file'}.gz";
		}
	else {
		&error($text{'doc_epath'});
		}
	}

&ui_print_header(undef, $text{'doc_title'}, "");

print "<table border width=100%>\n";
print "<tr $tb> <td><b>",&text('doc_header', $in{'file'}),"</b></td> </tr>\n";
print "<tr $cb> <td>";
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
if ($in{'file'} =~ /\.htm/i) {
	# Display HTML documentation
	($dir = $in{'file'}) =~ s/\/[^\/]+$//;
	while($line = <FILE>) {
		$line =~ s/href="([^"#][^"]*)"/href="view_doc.cgi?file=$dir\/$1"/ig;
		$line =~ s/href='([^'#][^']*)'/href='view_doc.cgi?file=$dir\/$1'/ig;
		$line =~ s/href=([^'"\s#][^'"\s>]*)/href='view_doc.cgi?file=$dir\/$1'/ig;
		print $line;
		}
	}
else {
	# Display text file
	print "<pre>";
	@for = split(/\s+/, $in{'for'});
	while($line = <FILE>) {
		$line =~ s/.\010//g;
		$line = &html_escape($line);
		foreach $f (@for) {
			$line =~ s/($f)/<b>$1<\/b>/ig;
			}
		print $line;
		}
	print "</pre>";
	}
close(FILE);
print "</td></tr></table><p>\n";

&ui_print_footer("", $text{'index_return'});

