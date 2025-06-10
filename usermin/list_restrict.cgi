#!/usr/local/bin/perl
# list_restrict.cgi
# Display usermin per-user or per-group module restrictions

require './usermin-lib.pl';
$access{'restrict'} || &error($text{'acl_ecannot'});
&ui_print_header(undef, $text{'restrict_title'}, "");

print &text('restrict_desc', "edit_acl.cgi"),"<p>\n";

my @usermods = &list_usermin_usermods();
my @links = &ui_link("edit_restrict.cgi?new=1", $text{'restrict_add'});
if (@usermods) {
	print &ui_links_row(\@links);
	my @tds = ( undef, undef, "width=10" );
	print &ui_columns_start([ $text{'restrict_who'},
				  $text{'restrict_what'},
				  $text{'restrict_move'} ], "100%", 0, \@tds);
	my $i = 0;
	foreach my $u (@usermods) {
		my @cols;
		push(@cols, &ui_link("edit_restrict.cgi?idx=$i",
			  $u->[0] eq "*" ? $text{'restrict_all'} :
			  $u->[0] =~ /^\@(.*)/ ?
				&text('restrict_group', "<tt>$1</tt>") :
			  $u->[0] =~ /^\// ?
				&text('restrict_file', "<tt>$u->[0]</tt>") :
				"<tt>$u->[0]</tt>"));
		my $mods = join(" ", map { "<tt>$_</tt>" } @{$u->[2]});
		push(@cols, !$mods ? $text{'restrict_nomods'} :
			     &text($u->[1] eq "+" ? 'restrict_plus' :
				   $u->[1] eq "-" ? 'restrict_minus' :
						    'restrict_set',
				   $mods));
		push(@cols, &ui_up_down_arrows(
				"move.cgi?idx=$i&up=1",
				"move.cgi?idx=$i&down=1",
				$u ne $usermods[0],
				$u ne $usermods[@usermods-1]));
		print &ui_columns_row(\@cols, \@tds);
		$i++;
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'restrict_none'}</b><p>\n";
	}
print &ui_links_row(\@links);

&ui_print_footer("", $text{'index_return'});

