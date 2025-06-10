#!/usr/local/bin/perl
# edit_res.cgi
# 
# extension of edit_res.cgi including display of 
# actual resource status and possibility to request
# a resource
#
# Christof Amelunxen, 22.08.2003
#

require './heartbeat-lib.pl';

# if called with parameter getserv this is a get_resource request
ReadParse();
if ($in{getserv} && -f $config{'pid_file'}) { 
	unless (check_status_resource($in{getserv})) {
	get_resource($in{getserv});
	# ugly hack to show the changed status immediately
	sleep 5;
	# redirect to url without appending parameters (to avoid reload button problem)
	redirect("$ENV{SCRIPT_NAME}");	
	exit 0;
	}
}	

# normal processing starts here
&ui_print_header(undef, $text{'res_title'}, "");

@res = &list_resources();
if (@res) {
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'res_node'}</b></td> ",
	      "<td><b>$text{'res_ips'}</b></td> ",
	      "<td><b>$text{'res_servs'}</b></td>\n",
	      "<td><b>$text{'res_active'}</b></td>\n",
	      "<td><b>$text{'res_getserv'}</b></td> </tr>\n";
	local $i = 0;
	foreach $r (@res) {
		print "<tr $cb> <td><a href='edit_node.cgi?idx=$i'>",
		      "$r->{'node'}</a></td>\n";
		printf "<td>%s</td>\n",
			$r->{'ips'} ? join(" ", @{$r->{'ips'}})
				    : $text{'res_none'};
		printf "<td>%s</td>\n", $r->{'servs'} ?
		    join("&nbsp;,&nbsp;", map { s/::/ /g; $_ } @{$r->{'servs'}})
		    : $text{'res_none'};
                if (check_status_resource(@{$r->{'ips'}})) {
                        print "<td bgcolor=#00FF00>$text{'res_up'}</td>";
                } else {
                        print "<td bgcolor=#FF0000>$text{'res_down'}</td>";
                }
                print "<td>";
                if ( -f $config{'pid_file'}) {
                        print "<form action=edit_res.cgi>\n";
                        print "<input type=hidden name=getserv value=@{$r->{'ips'}}>\n";
                        print "<input type=submit value='$text{'res_getserv'}'>\n";
                        print "</form>\n";
                } else {
                        print "$text{res_hbdown}";
                }
                print "</td></tr>";

		$i++;
		}
	print "</table>\n";
	}
else {
	print "<b>$text{'res_nores'}</b><p>\n";
	}
print &ui_link("edit_node.cgi?new=1", $text{'res_add'}),"<p>\n";

&ui_print_footer("", $text{'index_return'});

