#!/usr/local/bin/perl
# hint_form.cgi
# Display options for creating a new root zone

require './bind8-lib.pl';
$access{'master'} || &error($text{'hcreate_ecannot'});
$access{'ro'} && &error($text{'master_ero'});
&ui_print_header(undef, $text{'hcreate_title'}, "");

$conf = &get_config();
@views = &find("view", $conf);
foreach $v (@views) {
	local @vz = &find("zone", $v->{'members'});
	map { $view{$_} = $v } @vz;
	push(@zones, @vz);
	}
push(@zones, &find("zone", $conf));
foreach $z (@zones) {
	$tv = &find_value("type", $z->{'members'});
	if ($tv eq 'hint') {
		$file = &find_value("file", $z->{'members'});
		$hashint{$view{$z}}++;
		}
	}

print $text{'hcreate_desc'},"<p>\n";
print "<form action=\"create_hint.cgi\">\n";
print "<table>\n";

print "<tr> <td><b>$text{'hcreate_file'}</b></td>\n";
print "<td><input name=file size=30 value='$file'> ",
	&file_chooser_button("file"),"</td> </tr>\n";

print "<tr> <td valign=top><b>$text{'hcreate_real'}</b></td> <td>\n";
printf "<input type=radio name=real value=1 %s> $text{'hcreate_down'}<br>\n",
	$file ? "" : "checked";
print "<input type=radio name=real value=2> $text{'hcreate_webmin'}<br>\n";
printf "<input type=radio name=real value=3 %s> $text{'hcreate_keep'}\n",
	$file ? "checked" : "";
print "</td> </tr>\n";

if (@views) {
	print "<tr> <td><b>$text{'mcreate_view'}</b></td>\n";
	print "<td colspan=3><select name=view>\n";
	foreach $v (@views) {
		printf "<option value=%d>%s\n",
			$v->{'index'}, $v->{'value'} if (!$hashint{$v});
		}
	print "</select></td> </tr>\n";
	}

print "</table>\n";
print "<input type=submit value='$text{'create'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

