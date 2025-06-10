#!/usr/local/bin/perl
# index_user.cgi

require './proc-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "zone", !$no_module_config, 1);

&index_links("zone");
@procs = sort { $b->{'cpu'} <=> $a->{'cpu'} } &list_processes();
@procs = grep { &can_view_process($_) } @procs;
@zones = &unique(map { $_->{'_zone'} } @procs);
foreach $z (@zones) {
	print "<dt><font size=+1>",&text('index_inzone', "<tt>$z</tt>"),"</font><br>\n";
	print "<dd><table border width=90%>\n";
	print "<tr $tb> <td width=1% nowrap><b>$text{'pid'}</b></td>\n";
	print "         <td width=1%><b>$text{'cpu'}</b></td>\n";
	if ($info_arg_map{'_stime'}) {
		print "         <td width=1%><b>$text{'stime'}</b></td>\n";
		}
	print "         <td width=98%><b>$text{'command'}</b></td> </tr>\n";
	foreach $pr (grep { $_->{'_zone'} eq $z } @procs) {
		$p = $pr->{'pid'};
		print "<tr $cb>\n";
		if (&can_edit_process($pr->{'user'})) {
			print "<td>";
            print &ui_link("edit_proc.cgi?".$p, $p);
            print "</td>\n";
			}
		else {
			print "<td>$p</td>\n";
			}
		print "<td nowrap>$pr->{'cpu'}</td>\n";
		if ($info_arg_map{'_stime'}) {
			print "<td nowrap>",$pr->{'_stime'} || "<br>","</td>\n";
			}
		print "<td>",&html_escape(&cut_string($pr->{'args'})),
		      "</td>\n";
		print "</tr>\n";
		}
	print "</table><p>\n";
	}
print "</dl>\n";

&ui_print_footer("/", $text{'index'});

