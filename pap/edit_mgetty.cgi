#!/usr/local/bin/perl
# edit_mgetty.cgi
# Display the mgetty configuration for some serial port

require './pap-lib.pl';
$access{'mgetty'} || &error($text{'mgetty_ecannot'});
&ReadParse();
&foreign_require("inittab", "inittab-lib.pl");

if ($in{'new'}) {
	&ui_print_header(undef, $text{'mgetty_create'}, "");
	}
else {
	&ui_print_header(undef, $text{'mgetty_edit'}, "");
	@mgi = &mgetty_inittabs();
	($init) = grep { $_->{'id'} eq $in{'id'} } @mgi;
	}

print "<form action=save_mgetty.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=id value='$in{'id'}'>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'mgetty_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'mgetty_tty'}</b></td>\n";
print "<td><select name=tty>\n";
$found++ if ($in{'new'});
foreach $t (sort { "$a$b" =~ /^\/dev\/ttyS(\d+)\/dev\/ttyS(\d+)$/ ? $1 <=> $2 : 0 }
		 glob($config{'serials'})) {
	$t =~ s/^\/dev\///;
	local $f = $init->{'tty'} eq $t || $init->{'tty'} eq "/dev/$t";
	printf "<option value=%s %s>%s</option>\n",
		$t, $f ? "selected" : "",
		$t =~ /^ttyS(\d+)$/ ? &text('mgetty_ts', $1+1) :
		$t =~ /^term\/(\S+)$/ ? &text('mgetty_ts', uc($1)) : "/dev/$t";
	$found++ if ($f);
	}
printf "<option value='' %s>%s</option>\n",
	$found ? "" : "selected", $text{'mgetty_other'};
print "</select>\n";
printf "<input name=other size=20 value='%s'> %s</td>\n",
	$found ? "" : $init->{'tty'}, &file_chooser_button("other");

print "<td><b>$text{'mgetty_type'}</b></td>\n";
printf "<td><input name=direct type=radio value=1 %s> %s\n",
	$init->{'direct'} ? "checked" : "", $text{'mgetty_direct'};
printf "<input name=direct type=radio value=0 %s> %s</td> </tr>\n",
	$init->{'direct'} ? "" : "checked", $text{'mgetty_modem'};

print "<tr> <td><b>$text{'mgetty_speed'}</b></td>\n";
printf "<td><input type=radio name=speed_def value=1 %s> %s\n",
	$init->{'speed'} ? "" : "checked", $text{'mgetty_auto'};
printf "<input type=radio name=speed_def value=0 %s>\n",
	$init->{'speed'} ? "checked" : "";
printf "<input name=speed size=8 value='%s'> %s</td>\n",
	$init->{'speed'}, $text{'mgetty_baud'};

print "<td><b>$text{'mgetty_answer'}</b></td>\n";
printf "<td><input name=rings size=4 value='%s'> %s</td> </tr>\n",
	defined($init->{'rings'}) ? $init->{'rings'} : 1, $text{'mgetty_rings'};

print "<tr> <td><b>$text{'mgetty_mode'}</b></td>\n";
printf "<td><input type=radio name=mode value=0 %s> %s\n",
	$init->{'data'} || $init->{'fax'} ? "" : "checked", $text{'mgetty_df'};
printf "<input type=radio name=mode value=1 %s> %s\n",
	$init->{'data'} ? "checked" : "", $text{'mgetty_d'};
printf "<input type=radio name=mode value=2 %s> %s</td>\n",
	$init->{'fax'} ? "checked" : "", $text{'mgetty_f'};

print "<td><b>$text{'mgetty_back'}</b></td>\n";
printf "<td><input type=radio name=back_def value=1 %s> %s\n",
	$init->{'back'} ? "" : "checked", $text{'mgetty_back_def'};
printf "<input type=radio name=back_def value=0 %s>\n",
	$init->{'back'} ? "checked" : "";
printf "<input name=back size=4 value='%s'> %s</td> </tr>\n",
	$init->{'back'}, $text{'mgetty_secs'};

print "<tr> <td><b>$text{'mgetty_prompt'}</b></td>\n";
printf "<td colspan=3><input type=radio name=prompt_def value=1 %s> %s\n",
	$init->{'prompt'} ? "" : "checked", $text{'default'};
printf "<input type=radio name=prompt_def value=0 %s>\n",
	$init->{'prompt'} ? "checked" : "";
printf "<input name=prompt size=50 value='%s'></td> </tr>\n",
	$init->{'prompt'};

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
print "</table></form>\n";

&ui_print_footer("list_mgetty.cgi", $text{'mgetty_return'});

