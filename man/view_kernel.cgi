#!/usr/local/bin/perl
# view_kernel.cgi
# View some kernel doc file

require './man-lib.pl';
&ReadParse();

$in{'file'} = &simplify_path($in{'file'});
$in{'file'} !~ /[\\\&\;\`\'\"\|\*\?\<\>\^\(\)\[\]\{\}\$\n\r]/ ||
	&error($text{'kernel_epath'});
foreach $h (split(/\s+/, $config{'kernel_dir'})) {
	$ok++ if (&is_under_directory($config{'kernel_dir'}, $in{'file'}));
	}
$ok || &error($text{'kernel_epath'});
-r $in{'file'} || &error($text{'kernel_epath'});

&ui_print_header(undef, $text{'kernel_title'}, "");

# Work out compression format
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

$out = "";
if ($in{'file'} =~ /\.htm/i) {
	# Display HTML documentation
	($dir = $in{'file'}) =~ s/\/[^\/]+$//;
	while($line = <FILE>) {
		$line =~ s/href="([^"]+)"/href="view_doc.cgi?file=$dir\/$1"/ig;
		$line =~ s/href='([^']+)'/href='view_doc.cgi?file=$dir\/$1'/ig;
		$line =~ s/href=([^'"\s>]+)/href='view_doc.cgi?file=$dir\/$1'/ig;
		$out .= $line;
		}
	}
else {
	# Display text file
	$out .= "<pre>";
	@for = split(/\s+/, $in{'for'});
	while($line = <FILE>) {
		$line = &html_escape($line);
		foreach $f (@for) {
			$line =~ s/($f)/<b>$1<\/b>/ig;
			}
		$out .= $line;
		}
	$out .= "</pre>";
	}
close(FILE);
&show_view_table(&text('kernel_header', $in{'file'}), $out);

&ui_print_footer("", $text{'index_return'});

