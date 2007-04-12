#!/usr/local/bin/perl
# view_kde.cgi
# View some HTML KDE documentation

require './man-lib.pl';
&ReadParse();

$in{'file'} !~ /\.\./ ||
	&error($text{'kde_epath'});
$in{'file'} !~ /[\\\&\;\`\'\"\|\*\?\~\<\>\^\(\)\[\]\{\}\$\n\r]/ ||
	&error($text{'kde_epath'});
substr($in{'file'}, 0, length($config{'kde_dir'})) eq $config{'kde_dir'} ||
	&error($text{'kde_epath'});
-r $in{'file'} ||
	&error($text{'kde_epath'});

if ($in{'file'} =~ /\.(gif|jpg|jpeg|tif|png)$/i) {
	printf "Content-type: %s\n\n",
		$1 eq "gif" ? "image/gif" :
		$1 eq "jpg" || $1 eq "jpeg" ? "image/jpeg" :
		$1 eq "tif" ? "image/tiff" : "image/png";
	open(FILE, $in{'file'});
	while(read(FILE, $buf, 1024)) {
		print $buf;
		}
	close(FILE);
	}
else {
	&ui_print_header(undef, $text{'kde_title'}, "");

	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>",&text('kde_header', $in{'file'}),
	      "</b></td> </tr>\n";
	print "<tr $cb> <td>";
	($dir = $in{'file'}) =~ s/\/[^\/]+$//;
	open(FILE, $in{'file'});
	while($line = <FILE>) {
		$line =~ s/href="([^"]+)"/href="view_kde.cgi?file=$dir\/$1"/ig;
		$line =~ s/href='([^']+)'/href='view_kde.cgi?file=$dir\/$1'/ig;
		$line =~ s/href=([^'"\s>]+)/href='view_kde.cgi?file=$dir\/$1'/ig;
		$line =~ s/src="([^"]+)"/src="view_kde.cgi?file=$dir\/$1"/ig;
		$line =~ s/src='([^']+)'/src='view_kde.cgi?file=$dir\/$1'/ig;
		$line =~ s/src=([^'"\s>]+)/src='view_kde.cgi?file=$dir\/$1'/ig;
		print $line;
		}
	close(FILE);
	print "</td></tr></table><p>\n";

	&ui_print_footer("", $text{'index_return'});
	}

