#!/usr/local/bin/perl
# Show a list of all defined jails

use strict;
use warnings;
require './fail2ban-lib.pl';
our (%in, %text);

&ui_print_header(undef, $text{'jails_title'}, "");

my @jails = &list_jails();
print &ui_form_start("delete_jails.cgi", "post");
my @links = ( &select_all_link("d"),
	      &select_invert_link("d"),
	      &ui_link("edit_jail.cgi?new=1", $text{'jails_add'}) );
my @tds = ( "width=5" );
print &ui_links_row(\@links);
print &ui_columns_start([ "",
			  $text{'jails_name'},
			  $text{'jails_enabled'},
			  $text{'jails_filter'},
			  $text{'jails_action'} ]);
foreach my $j (@jails) {
	next if ($j->{'name'} eq 'DEFAULT');
	my $filter = &find_value("filter", $j);
	my $action_dir = &find("action", $j);
	my $action = "";
	if ($action_dir) {
		$action = join("&nbsp;|&nbsp;",
			map { /^([^\[]+)/; &html_escape("$1") }
			    @{$action_dir->{'words'}});
		}
	my $enabled = &find_value("enabled", $j);
	$enabled ||= "";
	print &ui_checked_columns_row([
		&ui_link("edit_jail.cgi?name=".&urlize($j->{'name'}),
			 $j->{'name'}),
		$enabled =~ /true|yes|1/i ? $text{'yes'} :
			"<font color=red>$text{'no'}</font>",
		&html_escape($filter),
		$action,
		], \@tds, "d", $j->{'name'});
	}
print &ui_columns_end();
print &ui_links_row(\@links);
print &ui_form_end([ [ undef, $text{'jails_delete'} ] ]);

print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row("edit_jaildef.cgi",
		      $text{'jails_def'}, $text{'jails_defdesc'});
print &ui_buttons_end();

&ui_print_footer("", $text{'index_return'});
