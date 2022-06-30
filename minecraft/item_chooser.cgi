#!/usr/local/bin/perl
# Output a list for choosing a Minecraft item


use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%text, %in);
&ReadParse(undef, undef, 2);

&popup_header($text{'chooser_title'});

print "<script>\n";
print "function select(f)\n";
print "{\n";
print "top.opener.ifield.value = f;\n";
print "top.close();\n";
print "return false;\n";
print "}\n";
print "</script>\n";

# Show all items
print &ui_form_start("item_chooser.cgi");
print "<b>$text{'chooser_search'}</b> ",
      &ui_textbox("search", $in{'search'}, 20)," ",
      &ui_submit($text{'chooser_ok'});
print &ui_form_end(),"<br>\n";

# Get the item list, and apply search
my @items = &list_minecraft_items();
if ($in{'search'}) {
	@items = grep { $_->{'name'} =~ /\Q$in{'search'}\E/i } @items;
	}

if (@items) {
	print &ui_columns_start([ $text{'chooser_id'},
				  $text{'chooser_num'},
				  $text{'chooser_name'} ]);
	foreach my $i (@items) {
		my $sel = $i->{'name'};
		if ($i->{'id'} =~ /:(\d+)$/) {
			$sel .= ":".$1;
			}
		print &ui_columns_row([
		    "<a href='' onClick='return select(\"$sel\")'>".
		      $i->{'name'}."</a>",
		    $i->{'id'},
		    &html_escape($i->{'desc'}),
		    ]);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'chooser_none'}</b><p>\n";
	}

&popup_footer();
