#!/usr/local/bin/perl
# edit_mod.cgi
# Edit one PAM authentication module for some service

require './pam-lib.pl';
&ReadParse();
@pam = &get_pam_config();
$pam = $pam[$in{'idx'}];
if ($in{'midx'} ne '') {
	$mod = $pam->{'mods'}->[$in{'midx'}];
	$module = $mod->{'module'};
	$module =~ s/^.*\///;
	$type = $mod->{'type'};
	&ui_print_header(undef, $text{'mod_edit'}, "");
	}
else {
	$module = $in{'module'};
	$type = $in{'type'};
	&ui_print_header(undef, $text{'mod_create'}, "");
	}


print "<form action=save_mod.cgi>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<input type=hidden name=midx value='$in{'midx'}'>\n";
print "<input type=hidden name=_module value='$in{'module'}'>\n";
print "<input type=hidden name=_type value='$in{'type'}'>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'mod_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'mod_name'}</b></td>\n";
$t = $text{'desc_'.$pam->{'name'}};
print "<td><tt>",&html_escape($pam->{'name'}),"</tt> ",
		$pam->{'desc'} ? "($pam->{'desc'})" :
		$t ? "($t)" : "","</td>\n";

print "<td><b>$text{'mod_mod'}</b></td>\n";
$t = $text{$module};
print "<td><tt>$module</tt> ",$t ? "($t)" : "","</td> </tr>\n";

print "<tr> <td><b>$text{'mod_type'}</b></td>\n";
print "<td>",$text{'mod_type_'.$type},"</td>\n";

print "<td><b>$text{'mod_control'}</b></td>\n";
print "<td><select name=control>\n";
foreach $c ('required', 'requisite', 'sufficient', 'optional') {
	printf "<option value=%s %s>%s (%s)\n",
		$c, $mod->{'control'} eq $c ? 'selected' : '',
		$text{'control_'.$c}, $text{'control_desc_'.$c};
	}
print "</select></td> </tr>\n";

if (-r "./$module.pl") {
	do "./$module.pl";
	if (!$module_has_no_args) {
		print "<tr> <td colspan=4><hr></td> </tr>\n";
		foreach $a (split(/\s+/, $mod->{'args'})) {
			if ($a =~ /^([^\s=]+)=(\S*)$/) {
				$args{$1} = $2;
				}
			else {
				$args{$a} = "";
				}
			}
		&display_module_args($pam, $mod, \%args);
		}
	}
else {
	print "<tr> <td colspan=4><hr></td> </tr>\n";
	print "<tr> <td><b>$text{'mod_args'}</b></td>\n";
	print "<td colspan=3><input name=args size=50 ",
	      "value='$mod->{'args'}'></td> </tr>\n";
	}

print "</table></td></tr></table>\n";
print "<table width=100%><tr>\n";
print "<td><input type=submit value='$text{'save'}'></td>\n";
if ($in{'midx'} ne '') {
	print "<td align=right><input type=submit name=delete ",
	      "value='$text{'delete'}'></td>\n";
	}
print "</tr></table>\n";
print "</form>\n";

&ui_print_footer("edit_pam.cgi?idx=$in{'idx'}", $text{'edit_return'},
	"", $text{'index_return'});

