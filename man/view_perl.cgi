#!/usr/local/bin/perl
# view_perl.cgi
# View perl module documentation

require './man-lib.pl';
&ReadParse();

$in{'mod'} !~ /[\\\&\;\`\'\"\|\*\?\~\<\>\^\(\)\[\]\{\}\$\n\r]/ ||
	&error($text{'perl_emod'});

&ui_print_header(undef, $text{'perl_title'}, "");

@for = split(/\s+/, $in{'for'});
&open_execute_command(DOC, "$perl_doc -t ".quotemeta($in{'mod'}), 1, 1);
$out = "<pre>";
while($line = <DOC>) {
	$line = &html_escape($line);
	foreach $f (@for) {
		$line =~ s/($f)/<b>$1<\/b>/ig;
		}
	$out .= $line;
	}
close(DOC);
$out .= "</pre>";
&show_view_table(&text('perl_header', $in{'mod'}), $out);

&ui_print_footer("", $text{'index_return'});

