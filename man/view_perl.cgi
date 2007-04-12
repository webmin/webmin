#!/usr/local/bin/perl
# view_perl.cgi
# View perl module documentation

require './man-lib.pl';
&ReadParse();

$in{'mod'} !~ /[\\\&\;\`\'\"\|\*\?\~\<\>\^\(\)\[\]\{\}\$\n\r]/ ||
	&error($text{'perl_emod'});

&ui_print_header(undef, $text{'perl_title'}, "");

print "<table border width=100%>\n";
print "<tr $tb> <td><b>",&text('perl_header', $in{'mod'}),"</b></td> </tr>\n";
print "<tr $cb> <td><pre>";
@for = split(/\s+/, $in{'for'});
&open_execute_command(DOC, "$perl_doc -t ".quotemeta($in{'mod'}), 1, 1);
while($line = <DOC>) {
	$line = &html_escape($line);
	foreach $f (@for) {
		$line =~ s/($f)/<b>$1<\/b>/ig;
		}
	print $line;
	}
close(DOC);
print "</pre></td></tr></table><p>\n";

&ui_print_footer("", $text{'index_return'});

