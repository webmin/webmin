#!/usr/local/bin/perl
# allmanual_form.cgi
# Display a text box for manually editing directives from one of the files

require './proftpd-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'manual_configs'}, "",
	undef, undef, undef, undef, &restart_button());

$conf = &get_config();
@files = &unique(map { $_->{'file'} } @$conf);
$in{'file'} = $files[0] if (!$in{'file'});
print "<form action=allmanual_form.cgi>\n";
print "<input type=submit value='$text{'manual_file'}'>\n";
print "<select name=file>\n";
foreach $f (@files) {
	printf "<option %s>%s</option>\n",
		$f eq $in{'file'} ? 'selected' : '', $f;
	$found++ if ($f eq $in{'file'});
	}
print "</select></form>\n";
$found || &error($text{'manual_efile'});

print "<form action=allmanual_save.cgi method=post ",
      "enctype=multipart/form-data>\n";
print "<input type=hidden name=file value='$in{'file'}'>\n";
print "<textarea name=data rows=20 cols=80>";
open(FILE, $in{'file'});
while(<FILE>) { print &html_escape($_); }
close(FILE);
print "</textarea><br>\n";
print "<input type=submit value='$text{'save'}'>\n";

&ui_print_footer("", $text{'index_return'});

