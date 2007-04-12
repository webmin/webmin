#!/usr/local/bin/perl
# sqlform.cgi
# Display the form for one SQL command on a page

require './custom-lib.pl';
&ReadParse();
@cmds = &list_commands();
$cmd = $cmds[$in{'idx'}];
&can_run_command($cmd) || &error($text{'form_ecannot'});

# Display form for command parameters
&ui_print_header(undef, $text{'form_title'}, "");
@a = @{$cmd->{'args'}};
($up) = grep { $_->{'type'} == 10 } @a;
if ($up) {
	print "<form action=sql.cgi method=post enctype=multipart/form-data>\n";
	}
elsif (@a) {
	print "<form action=sql.cgi method=post>\n";
	}
else {
	print "<form action=sql.cgi method=get>\n";
	}
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>",&html_escape($cmd->{'desc'}),"</b></td> </tr>\n";
print "<tr $cb> <td>",$cmd->{'html'},"<table width=100%>\n";

foreach $a (@{$cmd->{'args'}}) {
	print "<tr>\n" if (!$col);
	print "<td width=25%><b>",&html_escape($a->{'desc'}),
	      "</b></td> <td width=25% nowrap>\n";
	$n = $a->{'name'};
	if ($a->{'type'} == 0) {
		print "<input name=$n size=30>\n";
		}
	elsif ($a->{'type'} == 1 || $a->{'type'} == 2) {
		print "<input name=$n size=8> ",
			&user_chooser_button($n, 0);
		}
	elsif ($a->{'type'} == 3 || $a->{'type'} == 4) {
		print "<input name=$n size=8> ",
			&group_chooser_button($n, 0);
		}
	elsif ($a->{'type'} == 5 || $a->{'type'} == 6) {
		print "<input name=$n size=30 value='$a->{'opts'}'> ",
			&file_chooser_button($n, $a->{'type'}-5);
		}
	elsif ($a->{'type'} == 7) {
		print "<input type=radio name=$n value=1> $text{'yes'}\n";
		print "<input type=radio name=$n value=0 checked> $text{'no'}\n";
		}
	elsif ($a->{'type'} == 8) {
		print "<input name=$n type=password size=30>\n";
		}
	elsif ($a->{'type'} == 9) {
		print "<select name=$n>\n";
		foreach $l (&read_opts_file($a->{'opts'})) {
			print "<option value='$l->[0]'>",
			      "$l->[1]\n";
			}
		print "</select>\n";
		}
	elsif ($a->{'type'} == 10) {
		print "<input name=$n type=file size=20>\n";
		}
	elsif ($a->{'type'} == 11) {
		print "<textarea name=$n rows=4 cols=30>".
		      "</textarea>\n";
		}
	print "</td>\n";
	print "</tr>\n" if ($col);
	$col = !$col;
	}
print "<td colspan=2 width=50%></td> </tr>\n" if ($col);

print "<tr> <td colspan=4><input type=submit value='$text{'form_exec'}'>",
      "</td> </tr>\n";
print "</table></td></tr></table></form>\n";

&ui_print_footer("", $text{'index_return'});

