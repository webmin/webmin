#!/usr/local/bin/perl
# edit_feature.cgi
# Displays a form for editing or creating some M4 file entry, which may be a
# feature, define, mailer or other line.

require './sendmail-lib.pl';
require './features-lib.pl';
&ReadParse();
$features_access || &error($text{'features_ecannot'});

if ($in{'manual'}) {
	# Display manual edit form
	&ui_print_header(undef, $text{'feature_manual'}, "");

	print "<form action=manual_features.cgi method=post ",
	      "enctype=multipart/form-data>\n";
	print &text('feature_mdesc', "<tt>$config{'sendmail_mc'}</tt>"),
	      "<br>\n";
	print "<textarea name=data rows=20 cols=80>";
	open(FEAT, $config{'sendmail_mc'});
	while(<FEAT>) {
		print &html_escape($_);
		}
	close(FEAT);
	print "</textarea><br>\n";
	print "<input type=submit value='$text{'save'}'></form>\n";

	&ui_print_footer("list_features.cgi", $text{'features_return'});
	exit;
	}
if ($in{'new'}) {
	&ui_print_header(undef, $text{'feature_add'}, "");
	$feature = { 'type' => $in{'type'} };
	}
else {
	&ui_print_header(undef, $text{'feature_edit'}, "");
	@features = &list_features();
	$feature = $features[$in{'idx'}];
	}

print "<form action=save_feature.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<input type=hidden name=type value='$feature->{'type'}'>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'feature_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

if (!$in{'new'} && $feature->{'type'}) {
	print "<tr> <td><b>$text{'feature_old'}</b></td>\n";
	print "<td><tt>$feature->{'text'}</tt></td> </tr>\n";
	}

if ($feature->{'type'} == 0) {
	# Unsupported text line
	print "<tr> <td><b>$text{'feature_text'}</b></td>\n";
	printf "<td><input name=text size=50 value='%s'></td> </tr>\n",
		&html_escape($feature->{'text'});
	}
elsif ($feature->{'type'} == 1) {
	# A FEATURE() definition
	print "<tr> <td><b>$text{'feature_feat'}</b></td>\n";
	print "<td><select name=name>\n";
	foreach $f (&list_feature_types()) {
		printf "<option value=%s %s>%s\n",
			$f->[0], $feature->{'name'} eq $f->[0] ? 'selected' : '',
			$f->[1];
		}
	print "</select></td> </tr>\n";

	print "<tr> <td valign=top><b>$text{'feature_values'}</b></td> <td>\n";
	local @v = @{$feature->{'values'}};
	@v = ( "" ) if (!@v);
	for($i=0; $i<=@v; $i++) {
		print "<input name=value_$i size=50 value='$v[$i]'><br>\n";
		}
	print "</td> </tr>\n";
	}
elsif ($feature->{'type'} == 2 || $feature->{'type'} == 3) {
	# A define() or undefine()
	print "<tr> <td><b>$text{'feature_def'}</b></td>\n";
	print "<td><select name=name>\n";
	foreach $d (&list_define_types()) {
		printf "<option value=%s %s>%s\n",
			$d->[0], $d->[0] eq $feature->{'name'} ? "selected" : "",
			$d->[1];
		$found++ if ($d->[0] eq $feature->{'name'});
		}
	print "<option value=$feature->{'name'} selected>$feature->{'name'}\n"
		if (!$found && !$in{'new'});
	print "</select>\n";

	print "<tr> <td valign=top><b>$text{'feature_defval'}</b></td>\n";
	print "<td valign=top>\n";
	printf "<input type=radio name=undef value=0 %s> %s\n",
		$feature->{'type'} == 2 ? "checked" : "", $text{'feature_defmode1'};
	printf "<input name=value size=50 value='%s'><br>\n",
		$feature->{'value'};
	printf "<input type=radio name=undef value=1 %s> %s\n",
		$feature->{'type'} == 3 ? "checked" : "", $text{'feature_defmode0'};
	print "</td> </tr>\n";
	}
elsif ($feature->{'type'} == 4) {
	# A MAILER() definition
	print "<tr> <td><b>$text{'feature_mailer'}</b></td>\n";
	print "<td><select name=mailer>\n";
	foreach $m (&list_mailer_types()) {
		printf "<option value=%s %s>%s\n",
			$m->[0], $feature->{'mailer'} eq $m->[0] ? 'selected' : '',
			$m->[1];
		}
	print "</select></td> </tr>\n";
	}
elsif ($feature->{'type'} == 5) {
	# An OSTYPE() definition
	print "<tr> <td><b>$text{'feature_ostype'}</b></td>\n";
	print "<td><select name=ostype>\n";
	foreach $m (&list_ostype_types()) {
		printf "<option value=%s %s>%s\n",
			$m->[0], $feature->{'ostype'} eq $m->[0] ? 'selected' : '',
			$m->[1];
		}
	print "</select></td> </tr>\n";
	}

print "</table></td></tr></table>\n";
print "<table width=100%><tr>\n";
if ($in{'new'}) {
	print "<td><input type=submit value='$text{'create'}'></td>\n";
	}
else {
	print "<td><input type=submit value='$text{'save'}'></td>\n";
	print "<td align=right><input type=submit name=delete ",
	      "value='$text{'delete'}'></td>\n";
	}
print "</tr></table></form>\n";

&ui_print_footer("list_features.cgi", $text{'features_return'});

