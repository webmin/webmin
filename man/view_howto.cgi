#!/usr/local/bin/perl
# view_doc.cgi
# View some HOWTO doc file

require './man-lib.pl';
&ReadParse();

$in{'file'} = &simplify_path($in{'file'});
$in{'file'} !~ /[\\\&\;\`\'\"\|\*\?\~\<\>\^\(\)\[\]\{\}\$\n\r]/ ||
	&error($text{'howto_epath'});
foreach $h (split(/\s+/, $config{'howto_dir'})) {
	$ok++ if (&is_under_directory($h, $in{'file'}));
	}
$ok || &error($text{'howto_epath'});
-r $in{'file'} || &error($text{'howto_epath'});

&ui_print_header(undef, $text{'howto_title'}, "");

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

$out = "<pre>";
@for = split(/\s+/, $in{'for'});
while($line = <FILE>) {
	$line = &html_escape($line);
	foreach $f (@for) {
		$line =~ s/.\010//g;
		$line =~ s/($f)/<b>$1<\/b>/ig;
		}
	$out .= $line;
	}
close(FILE);
$out .= "</pre>";
&show_view_table(&text('howto_header', $in{'file'}), $out);

&ui_print_footer("", $text{'index_return'});

