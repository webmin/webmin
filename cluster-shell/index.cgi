#!/usr/local/bin/perl
# index.cgi
# Shows a form for running a command, allowing the selection of a server or
# group of servers to run it on.

require './cluster-shell-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", 0, 1);

print "<form action=run.cgi method=post>\n";
print "<table>\n";

print "<tr> <td><b>$text{'index_cmd'}</b></td>\n";
print "<td><input name=cmd size=60></td> </tr>\n";

open(COMMANDS, $commands_file);
chop(@commands = <COMMANDS>);
close(COMMANDS);
if (@commands) {
	print "<tr> <td align=right><b>$text{'index_old'}</b></td>\n";
	print "<td><select name=old>\n";
	foreach $c (&unique(@commands)) {
		print "<option>$c\n";
		}
	print "</select> <input type=submit name=clear ",
	      "value='$text{'index_clear'}'></td> </tr>\n";
	}

%serv = map { $_, 1 } split(/ /, $config{'server'});
print "<tr> <td valign=top><b>$text{'index_server'}</b></td>\n";
print "<td><select multiple size=5 name=server>\n";
printf "<option value=ALL %s>%s\n",
	$serv{'ALL'} ? 'selected' : '', $text{'index_all'};
printf "<option value=* %s>%s\n",
	$serv{'*'} ? 'selected' : '', $text{'index_this'};
foreach $s (grep { $_->{'user'} }
		 sort { $a->{'host'} cmp $b->{'host'} }
		      &servers::list_servers()) {
	printf "<option value=%s %s>%s\n",
		$s->{'host'}, $serv{$s->{'host'}} ? "selected" : "",
		$s->{'host'}.($s->{'desc'} ? " (".$s->{'desc'}.")" : "");
	}
foreach $g (&servers::list_all_groups()) {
	$gn = "group_".$g->{'name'};
	printf "<option value=%s %s>%s\n",
		$gn, $serv{$gn} ? "selected" : "",
		&text('index_group', $g->{'name'});
	}
print "</select></td> </tr>\n";

print "<tr>\n";
print "<td colspan=2><input type=submit value='$text{'index_run'}'></td> </tr>\n";

print "</table></form>\n";

&ui_print_footer("/", $text{'index'});

