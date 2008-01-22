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
print &ui_form_start("save_log.cgi");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});
print &ui_table_start($text{'edit_header1'}, "width=100%", 2);

# Log destination, starting with file
@dopts = ( [ 0, $text{'edit_file'},
	     &ui_textbox("file", $log->{'file'}, 40)." ".
	     &file_chooser_button("file")." ".
	     ($config{'sync'} ? "<br>".&ui_checkbox("sync", 1,
				$text{'edit_sync'}, $log->{'sync'}) : "") ]);

# Named pipe
if ($config{'pipe'} == 1) {
	push(@dopts, [ 1, $text{'edit_pipe'},
		       &ui_textbox("pipe", $log->{'pipe'}, 40)." ".
		       &file_chooser_button("pipe") ]);
	}
elsif ($config{'pipe'} == 2) {
	push(@dopts, [ 1, $text{'edit_pipe2'},
		       &ui_textbox("pipe", $log->{'pipe'}, 40) ]);
	}

# Socket file
if ($config{'socket'}) {
	push(@dopts, [ 5, $text{'edit_socket'},
		       &ui_textbox("socket", $log->{'socket'}, 40)." ".
		       &file_chooser_button("socket") ]);
	}

# Send to users
push(@dopts, [ 3, $text{'edit_users'},
	       &ui_textbox("users", join(" ", @{$log->{'users'}}), 40)." ".
	       &user_chooser_button("users", 1) ]);

# All users
push(@dopts, [ 4, $text{'edit_allusers'} ]);

# Remote host
push(@dopts, [ 2, $text{'edit_host'},
	       &ui_textbox("host", $log->{'host'}, 30) ]);

print &ui_table_row($text{'edit_logto'},
	&ui_radio_table("mode", $log->{'file'} ? 0 :
				$log->{'pipe'} ? 1 :
				$log->{'socket'} ? 5 :
				$log->{'host'} ? 2 :
				$log->{'users'} ? 3 :
				$log->{'all'} ? 4 : -1, \@dopts));

# Log active?
print &ui_table_row($text{'edit_active'},
	&ui_yesno_radio("active", $log->{'active'}));

if ($config{'tags'}) {
	# Tag name
	print &ui_table_row($text{'edit_tag'},
	    &ui_select("tag", $log->{'section'},
		[ map { [ $_->{'index'},
			  $_->{'tag'} eq '*' ? $text{'all'} : $_->{'tag'} ] }
		      grep { $_->{'tag'} } @$conf ]));
	}

print &ui_table_end();

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

