#!/usr/local/bin/perl
# list_locals.cgi
# Display local access records

require './postgresql-lib.pl';
$access{'users'} || &error($text{'local_ecannot'});
&ui_print_header(undef, $text{'local_title'}, "");

@locals = grep { $_->{'type'} eq 'local' } &get_hba_config();
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'host_db'}</b></td> ",
      "<td><b>$text{'host_auth'}</b></td> </tr>\n";
foreach $l (@locals) {
	print "<tr $cb>\n";
	print "<td>",$l->{'db'} eq 'all' ? $text{'host_all'} :
		     $l->{'db'} eq 'sameuser' ? $text{'host_same'} :
					        $l->{'db'},"</td>\n";
	print "<td>",$text{"host_$l->{'auth'}"},"</td>\n";
	print "</tr>\n";
	}
print "</table>\n";
print "<a href='edit_local.cgi?new=1'>$text{'local_add'}</a><p>\n";

&ui_print_footer("", $text{'index'});

