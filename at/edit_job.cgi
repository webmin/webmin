#!/usr/local/bin/perl
# edit_job.cgi
# Display a command for deletion

require './at-lib.pl';
&ReadParse();
@jobs = &list_atjobs();
($job) = grep { $_->{'id'} eq $in{'id'} } @jobs;
$job || &error($text{'edit_ejob'});
%access = &get_module_acl();
&can_edit_user(\%access, $job->{'user'}) || &error($text{'edit_ecannot'});

&ui_print_header(undef, $text{'edit_title'}, "");

print "<form action=delete_job.cgi>\n";
print "<input type=hidden name=id value='$in{'id'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'index_user'}</b></td>\n";
print "<td colspan=3>",&html_escape($job->{'user'}),"\n";
@uinfo = getpwnam($job->{'user'});
$uinfo[6] =~ s/,.*$//g;
print " (",&html_escape($uinfo[6]),")\n" if ($uinfo[6]);
print "</td> </tr>\n";

$date = localtime($job->{'date'});
print "<tr> <td><b>$text{'index_exec'}</b></td>\n";
print "<td>$date</td>\n";

$created = localtime($job->{'created'});
print "<td><b>$text{'index_created'}</b></td>\n";
print "<td>$created</td> </tr>\n";

print "<tr> <td valign=top><b>$text{'edit_cmd'}</b></td>\n";
print "<td colspan=3><font size=-1><pre>",
      &html_escape(join("\n", &wrap_lines($job->{'cmd'}, 80))),
      "</pre></font></td> </tr>\n";

print "<tr> <td colspan=4 align=right>",
      "<input type=submit name=run value='$text{'edit_run'}'> ",
      "<input type=submit value='$text{'edit_delete'}'></td> </tr>\n";

print "</table></td></tr></table></form>\n";
&ui_print_footer("", $text{'index_return'});

