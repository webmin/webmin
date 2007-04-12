#!/usr/local/bin/perl
# index.cgi
# List all at jobs and display a form for creating a new one
#
# F&AS : default parameters can be set 
#   ext_user : default user
#   ext_cmd  : default command

require './at-lib.pl';
use POSIX;
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
%access = &get_module_acl();
ReadParse();

# Show list of existing jobs
@jobs = &list_atjobs();
@jobs = grep { &can_edit_user(\%access, $_->{'user'}) } @jobs;
if (@jobs) {
	print &ui_form_start("delete_jobs.cgi", "post");
	@jobs = sort { $a->{'id'} <=> $b->{'id'} } @jobs;
	@tds = ( "width=5" );
	@links = ( &select_all_link("d"), &select_invert_link("d") );
	print &ui_links_row(\@links);
	print &ui_columns_start([
		"",
		$text{'index_id'},
		$text{'index_user'},
		$text{'index_exec'},
		$text{'index_created'},
		$text{'index_cmd'} ], 100, 0, \@tds);
	foreach $j (@jobs) {
		local @cols;
		push(@cols, "<a href='edit_job.cgi?id=$j->{'id'}'>".
			    "$j->{'id'}</a>");
		push(@cols, &html_escape($j->{'user'}));
		$date = localtime($j->{'date'});
		push(@cols, "<tt>$date</tt>");
		$created = localtime($j->{'created'});
		push(@cols, "<tt>$created</tt>");
		push(@cols, join("<br>", split(/\n/,
				&html_escape($j->{'realcmd'}))));
		print &ui_checked_columns_row(\@cols, \@tds, "d", $j->{'id'});
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
	print "<hr>\n";
	}


# Show form for creating a new At job
print "<form action=create_job.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'index_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'index_user'}</b></td>\n";
$dir = "/";
if ($access{'mode'} == 1) {
	print "<td><select name=user>\n";
	foreach $u (split(/\s+/, $access{'users'})) {
		print "<option>$u\n";
		}
	print "</select></td>\n";
	}
elsif ($access{'mode'} == 3) {
	print "<td><tt>$remote_user</tt></td>\n";
	print "<input type=hidden name=user value='$remote_user'>\n";
	@uinfo = getpwnam($remote_user);
	$dir = $uinfo[7];
	}
else {
	print "<td><input name=user value=\"$in{ext_user}\" size=8>",
		&user_chooser_button("user", 0),"</td>\n";
	}

@now = localtime(time());
print "<tr> <td><b>$text{'index_date'}</b></td>\n";
printf "<td><input name=day size=2 value='%d'>/", $now[3];
print "<select name=month>\n";
for($i=0; $i<12; $i++) {
	printf "<option value=%s %s>%s\n",
		$i, $now[4] == $i ? 'selected' : '', $text{"smonth_".($i+1)};
	}
print "</select>/";
printf "<input name=year size=4 value='%d'>\n", $now[5] + 1900;
print &date_chooser_button("day", "month", "year"),"</td>\n";

print "<td><b>$text{'index_time'}</b></td>\n";
print "<td><input name=hour size=2>:<input name=min size=2 value='00'></td> </tr>\n";

($date, $time) = split(/\s+/, &make_date(time()));

print "<tr> <td><b>$text{'index_cdate'}</b></td>\n";
print "<td>$date</td>\n";

print "<td><b>$text{'index_ctime'}</b></td>\n";
print "<td>$time</td> </tr>\n";

print "<tr> <td><b>$text{'index_dir'}</b></td>\n";
print "<td colspan=3><input name=dir size=40 value='$dir'></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'index_cmd'}</b></td>\n";
print "<td colspan=3><textarea rows=5 cols=40 name=cmd>$in{ext_cmd}</textarea></td></tr>\n";

print "<tr> <td colspan=4 align=right>",
      "<input type=submit value='$text{'create'}'></td> </tr>\n";

print "</table></td></tr></table></form>\n";

if ($access{'allow'} && $config{'allow_file'}) {
	# Show form to manage allowed and denied users
	@allow = &list_allowed();
	@deny = &list_denied();
	print "<hr>\n";
	print &ui_form_start("save_allow.cgi", "post");
	print &ui_table_start($text{'index_allow'}, undef, 2);
	print &ui_table_row($text{'index_amode'},
		    &ui_radio("amode", 
			@allow ? 1 : @deny ? 2 : 0,
			[ [ 0, $text{'index_amode0'} ],
			  [ 1, $text{'index_amode1'} ],
			  [ 2, $text{'index_amode2'} ] ]));
	print &ui_table_row("",
		    &ui_textarea("ausers", @allow ? join("\n", @allow) :
					  @deny ? join("\n", @deny) : undef,
				5, 50));
	print &ui_table_end();
	print &ui_form_end([ [ "save", $text{'save'} ] ]);
	}

&ui_print_footer("/", $text{'index'});

