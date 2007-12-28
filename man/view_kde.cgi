#!/usr/local/bin/perl
# view_kde.cgi
# View some HTML KDE documentation

require './man-lib.pl';
&ReadParse();

$in{'file'} = &simplify_path($in{'file'});
$in{'file'} !~ /[\\\&\;\`\'\"\|\*\?\~\<\>\^\(\)\[\]\{\}\$\n\r]/ ||
	&error($text{'kde_epath'});
&is_under_directory($config{'kde_dir'}, $in{'file'}) ||
	&error($text{'kde_epath'});
-r $in{'file'} ||
	&error($text{'kde_epath'});

# Just output if this is an image
$mt = &guess_mime_type($in{'file'});
if ($mt =~ /^image\//) {
	print "Content-type: $mt\r\n\r\n";
	print &read_file_contents($in{'file'});
	}
else {
	&ui_print_header(undef, $text{'kde_title'}, "");

	($dir = $in{'file'}) =~ s/\/[^\/]+$//;
	open(FILE, $in{'file'});
	while($line = <FILE>) {
		$line =~ s/href="([^"]+)"/href="view_kde.cgi?file=$dir\/$1"/ig;
		$line =~ s/href='([^']+)'/href='view_kde.cgi?file=$dir\/$1'/ig;
		$line =~ s/href=([^'"\s>]+)/href='view_kde.cgi?file=$dir\/$1'/ig;
		$line =~ s/src="([^"]+)"/src="view_kde.cgi?file=$dir\/$1"/ig;
		$line =~ s/src='([^']+)'/src='view_kde.cgi?file=$dir\/$1'/ig;
		$line =~ s/src=([^'"\s>]+)/src='view_kde.cgi?file=$dir\/$1'/ig;
		$out .= $line;
		}
	close(FILE);
	&show_view_table(&text('kde_header', $in{'file'}), $out);

	&ui_print_footer("", $text{'index_return'});
	}

