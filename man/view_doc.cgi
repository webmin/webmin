#!/usr/local/bin/perl
# view_doc.cgi
# View some package doc file

require './man-lib.pl';
&ReadParse();

$in{'file'} = &simplify_path($in{'file'});
$in{'file'} !~ /[\\\&\;\`\'\"\|\*\?\~\<\>\^\(\)\[\]\{\}\$\n\r]/ ||
	&error($text{'doc_epath'});
foreach $d (split(/\s+/, $config{'doc_dir'})) {
	$ok++ if (&is_under_directory($d, $in{'file'}));
	}
$ok++ if ($config{'custom_dir'} &&
	  &is_under_directory($config{'custom_dir'}, $in{'file'}));
$ok || &error($text{'doc_epath'});
if (!-r $in{'file'}) {
	if (-r "$in{'file'}.gz") {
		$in{'file'} = "$in{'file'}.gz";
		}
	else {
		&error($text{'doc_epath'});
		}
	}

# Just output if this is an image
$mt = &guess_mime_type($in{'file'});
if ($mt =~ /^image\//) {
	print "Content-type: $mt\r\n\r\n";
	print &read_file_contents($in{'file'});
	exit;
	}

&ui_print_header(undef, $text{'doc_title'}, "");

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
		$line =~ s/(href|src)="([^"#][^"]*)"/$1="view_doc.cgi?file=$dir\/$2"/ig;
		$line =~ s/(href|src)='([^'#][^']*)'/$1='view_doc.cgi?file=$dir\/$2'/ig;
		$line =~ s/(href|src)=([^'"\s#][^'"\s>]*)/$1='view_doc.cgi?file=$dir\/$2'/ig;
		$out .= $line;
		}
	}
else {
	# Display text file
	$out .= "<pre>";
	@for = split(/\s+/, $in{'for'});
	while($line = <FILE>) {
		$line =~ s/.\010//g;
		$line = &html_escape($line);
		foreach $f (@for) {
			$line =~ s/($f)/<b>$1<\/b>/ig;
			}
		$out .= $line;
		}
	$out .= "</pre>";
	}
close(FILE);
&show_view_table(&text('doc_header', $in{'file'}), $out);

&ui_print_footer("", $text{'index_return'});

