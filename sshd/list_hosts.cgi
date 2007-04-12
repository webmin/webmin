#!/usr/local/bin/perl
# Display client host sections

require './sshd-lib.pl';
&ui_print_header(undef, $text{'hosts_title'}, "", "hosts");

$hconf = &get_client_config();
$i = 0;
foreach $h (@$hconf) {
	if (lc($h->{'name'}) eq 'host') {
		push(@links, "edit_host.cgi?idx=$i");
		push(@icons, "images/host.gif");
		push(@titles, $h->{'values'}->[0] eq '*' ? "<i>$text{'hosts_all'}</i>" : &html_escape($h->{'values'}->[0]));
		}
	$i++;
	}
print &ui_subheading($text{'hosts_header'});
if (@links) {
	print "<a href='edit_host.cgi?new=1'>$text{'hosts_add'}</a> <br>\n";
	&icons_table(\@links, \@titles, \@icons);
	}
else {
	print "<b>$text{'hosts_none'}</b><p>\n";
	}
print "<a href='edit_host.cgi?new=1'>$text{'hosts_add'}</a> <p>\n";
&ui_print_footer("", $text{'index_return'});

