#!/usr/local/bin/perl
# edit_vgetty.cgi
# Display the vgetty configuration for some serial port

require './vgetty-lib.pl';
&ReadParse();
&foreign_require("inittab", "inittab-lib.pl");

if ($in{'new'}) {
	&ui_print_header(undef, $text{'vgetty_create'}, "");
	}
else {
	&ui_print_header(undef, $text{'vgetty_edit'}, "");
	@vgi = &vgetty_inittabs();
	($init) = grep { $_->{'id'} eq $in{'id'} } @vgi;
	}

print "<form action=save_vgetty.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=id value='$in{'id'}'>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'vgetty_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'vgetty_tty'}</b></td>\n";
print "<td colspan=3><select name=tty>\n";
$found++ if ($in{'new'});
opendir(DEV, "/dev");
foreach $t (sort { "$a$b" =~ /^ttyS(\d+)ttyS(\d+)$/ ? $1 <=> $2 : 0 }
		 readdir(DEV)) {
	if ($t =~ /^ttyS(\d+)$/) {
		local $f = $init->{'tty'} eq $t || $init->{'tty'} eq "/dev/$t";
		printf "<option value=%s %s>%s</option>\n",
			$t, $f ? "selected" : "", &text('vgetty_ts', $1+1);
		$found++ if ($f);
		}
	}
closedir(DEV);
printf "<option value='' %s>%s</option>\n",
	$found ? "" : "selected", $text{'vgetty_other'};
print "</select>\n";
printf "<input name=other size=20 value='%s'> %s</td> </tr>\n",
	$found ? "" : $init->{'tty'}, &file_chooser_button("other");

@conf = &get_config();
$rings = &find_value("rings", \@conf);
if ($rings =~ /^\//) {
	$tf = $in{'new'} ? undef : &tty_opt_file($rings, $init->{'tty'});
	print "<tr> <td><b>$text{'vgetty_rings'}</b></td>\n";
	printf "<td><input type=radio name=rings_def value=1 %s> %s\n",
		-r $tf ? "" : "checked", $text{'vgetty_default'};
	printf "<input type=radio name=rings_def value=0 %s> %s\n",
		-r $tf ? "checked" : "";
	open(TF, $tf);
	chop($rc = <TF>);
	close(TF);
	print "<input name=rings size=5 value='$rc'></td> </tr>\n";
	}

$ans = &find_value("answer_mode", \@conf);
if ($ans =~ /^\//) {
	$tf = $in{'new'} ? undef : &tty_opt_file($ans, $init->{'tty'});
	print "<tr> <td><b>$text{'vgetty_ans'}</b></td>\n";
	printf "<td><input type=radio name=ans_def value=1 %s> %s\n",
		-r $tf ? "" : "checked", $text{'vgetty_default'};
	printf "<input type=radio name=ans_def value=0 %s> %s\n",
		-r $tf ? "checked" : "";
	open(TF, $tf);
	chop($am = <TF>);
	close(TF);
	print &answer_mode_input($am, "ans"),"</td> </tr>\n";
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
print "</table></form>\n";

&ui_print_footer("list_vgetty.cgi", $text{'vgetty_return'});

