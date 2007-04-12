#!/usr/local/bin/perl
# list_pack.cgi
# List all the files in some package

require './cluster-software-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'list_title'}, "");

@servers = &list_servers();
($s) = grep { $_->{'id'} == $in{'server'} } @servers;
&remote_foreign_require($s->{'host'}, "software", "software-lib.pl");

print &ui_subheading(&text('list_files', "<tt>$in{'package'}</tt>",
		   $s->{'desc'} ? $s->{'desc'} : $s->{'host'}));
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'list_path'}</b></td> ",
      "<td><b>$text{'list_owner'}</b></td> ",
      "<td><b>$text{'list_group'}</b></td> ",
      "<td><b>$text{'list_type'}</b></td> ",
      "<td><b>$text{'list_size'}</b></td> ",
      "<td><b>$text{'list_status'}</b></td> </tr>\n";
$n = &remote_foreign_call($s->{'host'}, "software",
			  "check_files", $in{'package'});
$files = &remote_eval($s->{'host'}, "software", "\\%files");
for($i=0; $i<$n; $i++) {
	$sz = $files->{$i,'size'};
	$ty = $files->{$i,'type'};
	print "<tr $cb>\n";
	if ($ty == 3 || $ty == 4) {
		print "<td valign=top>$files->{$i,'path'} -> ",
		      "$files->{$i,'link'}</td>\n";
		print "<td><br></td> <td><br></td>\n";
		}
	else {
		print "<td valign=top><table width=100% cellpadding=0 ",
		      "cellspacing=0><tr><td>",
		      "$files->{$i,'path'}</td> <td align=right>\n";
		if ($ty == 0 || $ty == 5) {
			print "<a href='view.cgi",$files->{$i,'path'},
			      "'>$text{'list_view'}</a>";
			}
		print "</td></tr>","</table></td>\n";
		print "<td valign=top>$files->{$i,'user'}</td>\n";
		print "<td valign=top>$files->{$i,'group'}</td>\n";
		}
	print "<td valign=top>$software::type_map[$ty]</td>\n";
	if ($ty != 0) { $sz = "<br>"; }
	elsif ($sz > 1000000) { $sz = sprintf "%d MB", $sz/1000000; }
	elsif ($sz > 1000) { $sz = sprintf "%d kB", $sz/1000; }
	else { $sz .= " B"; }
	print "<td valign=top>$sz</td>\n";
	$err = $files->{$i,'error'};
	if ($err) {
		$err =~ s/</&lt;/g;
		$err =~ s/>/&gt;/g;
		$err =~ s/\n/<br>/g;
		print "<td valign=top><font color=#ff0000>$err</font></td>\n";
		}
	else { print "<td valign=top>$text{'list_ok'}</td>\n"; }
	print "</tr>\n";
	}
print "</table><p>\n";

&remote_finished();
&ui_print_footer("edit_pack.cgi?package=".&urlize($in{'package'})."&search=".&urlize($in{'search'}), $text{'edit_return'});

