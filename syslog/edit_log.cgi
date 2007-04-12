#!/usr/local/bin/perl
# edit_log.cgi
# Display a form for editing or creating a new log destination

require './syslog-lib.pl';
&ReadParse();
$access{'noedit'} && &error($text{'edit_ecannot'});
$access{'syslog'} || &error($text{'edit_ecannot'});
$conf = &get_config();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'create_title'}, "");
	$log = { 'active' => '1',
		 'sync' => 1,
		 'file' => -d '/var/log' ? '/var/log/' :
			   -d '/var/adm' ? '/var/adm/' : undef };
	}
else {
	&ui_print_header(undef, $text{'edit_title'}, "");
	$log = $conf->[$in{'idx'}];
	&can_edit_log($log) || &error($text{'edit_ecannot2'});
	}

# Log destination section
print "<form action=save_log.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_header1'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'edit_logto'}</b></td>\n";
printf "<td><input type=radio name=mode value=0 %s> %s</td>\n",
	$log->{'file'} ? 'checked' : '', $text{'edit_file'};
printf "<td><input name=file size=40 value='%s'> %s\n",
	$log->{'file'}, &file_chooser_button("file");
if ($config{'sync'}) {
	printf "<input type=checkbox name=sync value=1 %s> %s\n",
		$log->{'sync'} ? 'checked' : '', $text{'edit_sync'};
	}
print "</td> </tr>\n";

if ($config{'pipe'} == 1) {
	print "<tr> <td></td>\n";
	printf "<td><input type=radio name=mode value=1 %s> %s</td>\n",
		$log->{'pipe'} ? 'checked' : '', $text{'edit_pipe'};
	printf "<td><input name=pipe size=40 value='%s'> %s</td> </tr>\n",
		$log->{'pipe'}, &file_chooser_button("pipe");
	}
elsif ($config{'pipe'} == 2) {
	print "<tr> <td></td>\n";
	printf "<td><input type=radio name=mode value=1 %s> %s</td>\n",
		$log->{'pipe'} ? 'checked' : '', $text{'edit_pipe2'};
	printf "<td><input name=pipe size=40 value='%s'></td> </tr>\n",
		$log->{'pipe'};
	}

if ($config{'socket'}) {
	print "<tr> <td></td>\n";
	printf "<td><input type=radio name=mode value=5 %s> %s</td>\n",
		$log->{'socket'} ? 'checked' : '', $text{'edit_socket'};
	printf "<td><input name=socket size=40 value='%s'> %s</td> </tr>\n",
		$log->{'socket'}, &file_chooser_button("socket");
	}

print "<tr> <td></td>\n";
printf "<td><input type=radio name=mode value=2 %s> %s</td>\n",
	$log->{'host'} ? 'checked' : '', $text{'edit_host'};
printf "<td><input name=host size=20 value='%s'></td> </tr>\n",
	$log->{'host'};

print "<tr> <td></td>\n";
printf "<td><input type=radio name=mode value=3 %s> %s</td>\n",
	$log->{'users'} ? 'checked' : '', $text{'edit_users'};
printf "<td><input name=users size=40 value='%s'> %s</td> </tr>\n",
	join(" ", @{$log->{'users'}}), &user_chooser_button("users", 1);

print "<tr> <td></td>\n";
printf "<td colspan=2><input type=radio name=mode value=4 %s> %s</td> </tr>\n",
	$log->{'all'} ? 'checked' : '', $text{'edit_allusers'};

print "<tr> <td><b>$text{'edit_active'}</b></td> <td colspan=2>\n";
printf "<input type=radio name=active value=1 %s> %s\n",
	$log->{'active'} ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=active value=0 %s> %s</td> </tr>\n",
	$log->{'active'} ? '' : 'checked', $text{'no'};

if ($config{'tags'}) {
	print "<tr> <td><b>$text{'edit_tag'}</b></td> <td colspan=2>\n";
	print "<select name=tag>\n";
	foreach $t (grep { $_->{'tag'} } @$conf) {
		printf "<option %s value=%s>%s\n",
			$log->{'section'} eq $t ? 'selected' : '',
			$t->{'index'},
			$t->{'tag'} eq '*' ? $text{'all'} : $t->{'tag'};
		}
	print "</select></td> </tr>\n";
	}

print "</table></td></tr></table><p>\n";

# Log selection section
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_header2'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

@facil = split(/\s+/, $config{'facilities'});
print "<tr> <td><b>$text{'edit_facil'}</b></td> ",
      "<td><b>$text{'edit_pri'}</b></td> </tr>\n";
$i = 0;
foreach $s (@{$log->{'sel'}}, ".none") {
	($f, $p) = split(/\./, $s);
	$p =~ s/warn$/warning/;
	$p =~ s/panic$/emerg/;
	$p =~ s/error$/err/;

	print "<tr> <td>\n";
	printf "<input type=radio name=fmode_$i value=0 %s>\n",
		$f =~ /,/ ? '' : 'checked';
	print "<select name=facil_$i>\n";
	printf "<option value='' %s>&nbsp;\n", $f ? '' : 'selected';
	printf "<option value='*' %s>%s\n",
		$f eq '*' ? 'selected' : '', $text{'edit_all'};
	local $ffound = ($f eq '*');
	foreach $fc (@facil) {
		printf "<option %s>%s\n",
			$fc eq $f ? 'selected' : '', $fc;
		$ffound++ if ($fc eq $f);
		}
	print "<option selected>$f\n" if (!$ffound && $f !~ /,/);
	print "</select>&nbsp;\n";
	printf "<input type=radio name=fmode_$i value=1 %s> %s\n",
		$f =~ /,/ ? 'checked' : '', $text{'edit_many'};
	printf "<input name=facils_$i size=25 value='%s'></td>\n",
		$f =~ /,/ ? join(" ", split(/,/, $f)) : '';

	print "<td>\n";
	printf "<input type=radio name=pmode_$i value=0 %s> %s&nbsp;\n",
		$p eq 'none' ? 'checked' : '', $text{'edit_none'};
	if ($config{'pri_all'}) {
		printf "<input type=radio name=pmode_$i value=1 %s> %s&nbsp;\n",
			$p eq '*' ? 'checked' : '', $text{'edit_all'};
		}
	printf "<input type=radio name=pmode_$i value=2 %s>\n",
		$p eq 'none' || $p eq '*' ? '' : 'checked';

	if ($config{'pri_dir'} == 1) {
		print "<select name=pdir_$i>\n";
		printf "<option value='' selected>\n"
			if ($p eq '*' || $p eq 'none');
		printf "<option value='' %s>%s\n",
			$p =~ /\!|=/ ? '' : 'selected', $text{'edit_pdir0'};
		printf "<option value='=' %s>%s\n",
			$p =~ /^=/ ? 'selected' : '', $text{'edit_pdir1'};
		printf "<option value='!' %s>%s\n",
			$p =~ /^![^=]/ ? 'selected' : '', $text{'edit_pdir2'};
		printf "<option value='!=' %s>%s\n",
			$p =~ /^!=/ ? 'selected' : '', $text{'edit_pdir3'};
		print "</select>\n";
		$p =~ s/^[!=]*//;
		}
	elsif ($config{'pri_dir'} == 2) {
		print "<select name=pdir_$i>\n";
		printf "<option value='' selected>\n"
			if ($p eq '*' || $p eq 'none');
		local $pfx = $p =~ /^([<=>]+)/ ? $1 : undef;
		printf "<option value='' %s>&gt;=\n",
			$pfx eq '>=' || $pfx eq '=>' || !$pfx ? 'selected' : '';
		printf "<option value='>' %s>&gt;\n",
			$pfx eq '>' ? 'selected' : '';
		printf "<option value='<=' %s>&lt;=\n",
			$pfx eq '<=' || $pfx eq '=<' ? 'selected' : '';
		printf "<option value='<' %s>&lt;\n",
			$pfx eq '<' ? 'selected' : '';
		printf "<option value='<>' %s>&lt;&gt;\n",
			$pfx eq '<>' || $pfx eq '><' ? 'selected' : '';
		print "</select>\n";
		$p =~ s/^[<=>]*//;
		}
	else {
		print $text{'edit_pdir0'};
		}

	local $pfound = ($p eq '*' || $p eq 'none');
	print "<select name=pri_$i>\n";
	print "<option selected>\n" if ($p eq '*' || $p eq 'none');
	foreach $pr (&list_priorities()) {
		printf "<option %s>%s\n",
			$p =~ /$pr/ ? 'selected' : '', $pr;
		$pfound++ if ($p =~ /$pr/);
		}
	print "<option selected>$p\n" if (!$pfound);
	print "</select></td></tr>\n";
	$i++;
	}
print "</table></td></tr></table>\n";

print "<table width=100%><tr>\n";
print "<td><input type=submit value='$text{'save'}'></td>\n";
if (!$in{'new'}) {
	if ($log->{'file'} && -f $log->{'file'}) {
		print "<td align=center><input type=submit name=view ",
		      "value='$text{'edit_view'}'></td>\n";
		}
	print "<td align=right><input type=submit name=delete ",
	      "value='$text{'delete'}'></td>\n";
	}
print "</tr></table></form>\n";

&ui_print_footer("", $text{'index_return'});

