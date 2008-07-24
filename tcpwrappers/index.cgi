#!/usr/local/bin/perl
# index.cgi

require './tcpwrappers-lib.pl';

&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);

# ALLOWED HOSTS & DENIED HOSTS
foreach my $type ('allow', 'deny') {
    my $file = $type eq 'allow' ? $config{'hosts_allow'} : $config{'hosts_deny'};
    @rules = &list_rules($file);
    print "<font size=+1>".($type eq 'allow' ? $text{'index_allowtitle'} : $text{'index_denytitle'})."</font><p />\n";
    if (@rules) {
	print &ui_form_start("delete_rules.cgi", "post");
	print &ui_hidden($type, 1),"\n";
	print &select_all_link("d"),"\n";
	print &select_invert_link("d"),"\n";
	print "<a href='edit_rule.cgi?$type=1&new=1'>$text{'index_add'}</a><br />\n";
	
	@tds = ( "width=5" );
	print &ui_columns_start([
				 "",
				 $text{'index_service'},
				 $text{'index_hosts'},
				 $text{'index_cmd'},
				 ], "width=100%", 0, \@tds);
	foreach my $r (@rules) {
	    print &ui_checked_columns_row([
					   "<a href='edit_rule.cgi?$type=1&id=$r->{'id'}'>$r->{'service'}</a>",
					   $r->{'host'},
					   $r->{'cmd'} ? join("<br>", split /:/, $r->{'cmd'}) : $text{'index_none'},
					   ], \@tds, "d", $r->{'id'});
	}
	print &ui_columns_end();
	
	print &select_all_link("d"),"\n";
	print &select_invert_link("d"),"\n";
	print "<a href='edit_rule.cgi?$type=1&new=1'>$text{'index_add'}</a><br />\n";
	print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
    } else {
	if (-r $file) {
	    print "<b>".&text('index_norule', $file)."</b><br />\n";
	    print "<a href='edit_rule.cgi?$type=1&new=1'>$text{'index_add'}</a><p />\n";
	} else {
	    print "<br>".&text('index_nofile', $file)."</b><p />\n";
	}
    }   
    print "<hr />\n" if ($type eq 'allow');
}

&ui_print_footer("/", $text{'index_return'});
