#!/usr/local/bin/perl
# edit_defaults.cgi
# Display a form for editing default options

require './xinetd-lib.pl';
&ui_print_header(undef, $text{'defs_title'}, "");

foreach $xi (&get_xinetd_config()) {
	if ($xi->{'name'} eq 'defaults') {
		$defs = $xi;
		}
	}
$q = $defs->{'quick'};

print "<form action=save_defaults.cgi>\n";
print "<input type=hidden name=idx value='$defs->{'index'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'defs_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td valign=top><b>$text{'serv_from'}</b></td>\n";
printf "<td><input type=radio name=from_def value=1 %s> %s\n",
	$q->{'only_from'} ? '' : 'checked', $text{'serv_from_def'};
printf "<input type=radio name=from_def value=0 %s> %s<br>\n",
	$q->{'only_from'} ? 'checked' : '', $text{'serv_from_sel'};
print "<textarea name=from rows=4 cols=20>",
	join("\n", @{$q->{'only_from'}}),"</textarea></td>\n";

print "<td valign=top><b>$text{'serv_access'}</b></td>\n";
printf "<td><input type=radio name=access_def value=1 %s> %s\n",
	$q->{'no_access'} ? '' : 'checked', $text{'serv_access_def'};
printf "<input type=radio name=access_def value=0 %s> %s<br>\n",
	$q->{'no_access'} ? 'checked' : '', $text{'serv_access_sel'};
print "<textarea name=access rows=4 cols=20>",
	join("\n", @{$q->{'no_access'}}),"</textarea></td> </tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

$lt = $q->{'log_type'}->[0] eq 'SYSLOG' ? 1 :
      $q->{'log_type'}->[0] eq 'FILE' ? 2 : 0;
print "<tr> <td valign=top><b>$text{'defs_log'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=log_mode value=0 %s> %s<br>\n",
	$lt == 0 ? 'checked' : '', $text{'defs_log_def'};

printf "<input type=radio name=log_mode value=1 %s> %s\n",
	$lt == 1 ? 'checked' : '', $text{'defs_facility'};
%sconfig = &foreign_config("syslog");
&foreign_require("syslog", "syslog-lib.pl");
print "<select name=facility>\n";
foreach $f (split(/\s+/, $sconfig{'facilities'})) {
	printf "<option %s>%s\n",
		$lt == 1 && $q->{'log_type'}->[1] eq $f ? 'selected' : '', $f;
	}
print "</select> $text{'defs_level'}\n";
print "<select name=level>\n";
printf "<option value='' %s>%s\n",
	$lt != 1 || !$q->{'log_type'}->[2] ? 'selected' : '', $text{'default'};
foreach $l (&foreign_call("syslog", "list_priorities")) {
	printf "<option %s>%s\n",
		$lt == 1 && $q->{'log_type'}->[2] eq $l ? 'selected' : '', $l;
	}
print "</select><br>\n";

printf "<input type=radio name=log_mode value=2 %s> %s\n",
	$lt == 2 ? 'checked' : '', $text{'defs_file'};
printf "<input name=file size=35 value='%s'> %s<br>\n",
	$lt == 2 ? $q->{'log_type'}->[1] : '', &file_chooser_button("file");
printf "&nbsp;&nbsp;&nbsp;%s <input name=soft size=6 value='%s'>\n",
	$text{'defs_soft'}, $lt == 2 ? $q->{'log_type'}->[2] : '';
printf "&nbsp;&nbsp;%s <input name=hard size=6 value='%s'></td> </tr>\n",
	$text{'defs_hard'}, $lt == 2 ? $q->{'log_type'}->[3] : '';

print "<tr> <td valign=top><b>$text{'defs_success'}</b></td>\n";
print "<td><select name=success multiple size=5>\n";
foreach $s ('PID', 'HOST', 'USERID', 'EXIT', 'DURATION') {
	printf "<option value=%s %s>%s\n",
		$s, &indexof($s, @{$q->{'log_on_success'}})<0 ? '' : 'selected',
		$text{"defs_success_".lc($s)};
	}
print "</select></td>\n";

print "<td valign=top><b>$text{'defs_failure'}</b></td>\n";
print "<td><select name=failure multiple size=5>\n";
foreach $s ('HOST', 'USERID', 'ATTEMPT') {
	printf "<option value=%s %s>%s\n",
		$s, &indexof($s, @{$q->{'log_on_failure'}})<0 ? '' : 'selected',
		$text{"defs_failure_".lc($s)};
	}
print "</select></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

