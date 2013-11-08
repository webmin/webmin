#!/usr/local/bin/perl
# edit.cgi
# Edit an existing or new cluster cron job

require './cluster-cron-lib.pl';
&ReadParse();

if (!$in{'new'}) {
	@jobs = &list_cluster_jobs();
	($job) = grep { $_->{'cluster_id'} eq $in{'id'} } @jobs;
	&ui_print_header(undef, $text{'edit_title'}, "");
	}
else {
	&ui_print_header(undef, $text{'create_title'}, "");
	$job = { 'mins' => '*',
		 'hours' => '*',
		 'days' => '*',
		 'months' => '*',
		 'weekdays' => '*',
		 'active' => 1 };
	}

print "<form action=save.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=id value='$in{'id'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$cron::text{'edit_details'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$cron::text{'edit_user'}</b></td>\n";
print "<td><input name=user size=8 value=\"$job->{'cluster_user'}\"> ",
	&user_chooser_button("user", 0),"</td>\n";

%serv = map { $_, 1 } split(/ /, $job->{'cluster_server'});
print "<td rowspan=4 valign=top><b>$text{'edit_servers'}</b></td>\n";
print "<td rowspan=4 valign=top><select multiple size=8 name=server>\n";
printf "<option value=ALL %s>%s</option>\n",
	$serv{'ALL'} ? 'selected' : '', $text{'edit_all'};
printf "<option value=* %s>%s</option>\n",
	$serv{'*'} ? 'selected' : '', $text{'edit_this'};
foreach $s (grep { $_->{'user'} }
		 sort { $a->{'host'} cmp $b->{'host'} }
		      &servers::list_servers()) {
	printf "<option value=%s %s>%s</option>\n",
		$s->{'host'}, $serv{$s->{'host'}} ? "selected" : "",
		$s->{'host'}.($s->{'desc'} ? " ($s->{'desc'})" : "");
	}
foreach $g (sort { $a->{'name'} cmp $b->{'name'} }
		 &servers::list_all_groups()) {
	$gn = "group_".$g->{'name'};
	printf "<option value=%s %s>%s</option>\n",
		$gn, $serv{$gn} ? "selected" : "",
		&text('edit_group', $g->{'name'});
	}
print "</select></td> </tr>\n";

print "<tr> <td> <b>$cron::text{'edit_active'}</b></td>\n";
printf "<td><input type=radio name=active value=1 %s> $text{'yes'}\n",
	$job->{'active'} ? "checked" : "";
printf "<input type=radio name=active value=0 %s> $text{'no'}</td> </tr>\n",
	$job->{'active'} ? "" : "checked";

# Normal cron job.. can edit command
print "<tr> <td><b>$cron::text{'edit_command'}</b></td>\n";
print "<td><input name=cmd size=30 ",
      "value='",&html_escape($job->{'cluster_command'}),"'></td> </tr>\n";

if ($cron::config{'cron_input'}) {
	@lines = split(/%/ , $job->{'cluster_input'});
	print "<tr> <td valign=top><b>$cron::text{'edit_input'}</b></td>\n";
	print "<td><textarea name=input rows=3 cols=30>",
	      join("\n" , @lines),"</textarea></td> </tr>\n";
	}

print "</table></td></tr></table><p>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td colspan=5><b>$cron::text{'edit_when'}</b></td> </tr>\n";
&cron::show_times_input($job, 1);
print "</table>\n";

if (!$in{'new'}) {
	print "<table width=100%>\n";
	print "<tr> <td align=left><input type=submit value=\"$text{'save'}\"></td>\n";

	print "</form><form action=\"exec.cgi\">\n";
	print "<input type=hidden name=id value=\"$in{'id'}\">\n";
	print "<td align=center>",
	      "<input type=submit value=\"$cron::text{'edit_run'}\"></td>\n";

	print "</form><form action=\"delete.cgi\">\n";
	print "<input type=hidden name=id value=\"$in{'id'}\">\n";
	print "<td align=right><input type=submit value=\"$cron::text{'delete'}\"></td> </tr>\n";
	print "</form></table><p>\n";
	}
else {
	print "<input type=submit value=\"$text{'create'}\"></form><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

