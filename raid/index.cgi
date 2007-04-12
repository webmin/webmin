#!/usr/local/bin/perl
# index.cgi
# Display all RAID devices

require './raid-lib.pl';

# Check if raid is installed
if (!-r $config{'mdstat'}) {
	&error_exit(&text('index_emdstat', "<tt>$config{'mdstat'}</tt>"));
	}
if (&has_command("mdadm")) {
	# Using mdadm commands
	$raid_mode = "mdadm";
	}
elsif (&has_command('mkraid') && &has_command('raidstart')) {
	# Using raid tools commands
	$raid_mode = "raidtools";
	}
else {
	&error_exit($text{'index_eprogs'});
	}
&open_tempfile(MODE, ">$module_config_directory/mode");
&print_tempfile(MODE, $raid_mode,"\n");
&close_tempfile(MODE);

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("raid", "man", "doc"),
	undef, undef, &text('index_'.$raid_mode));

# Display configured raid devices
$conf = &get_raidtab();
if (@$conf) {
	&show_button();
	foreach $c (@$conf) {
		$lvl = &find_value('raid-level', $c->{'members'});
		push(@titles, &html_escape($c->{'value'}));
		push(@images, $c->{'active'} ? "images/$lvl.gif"
					     : "images/$lvl.ia.gif");
		push(@links, "view_raid.cgi?idx=$c->{'index'}");
		}
	&icons_table(\@links, \@titles, \@images);
	}
else {
	print "<p><b>$text{'index_none'}</b><p>\n";
	}
&show_button();

&ui_print_footer("/", $text{'index'});

sub show_button
{
print &ui_form_start("raid_form.cgi");
print &ui_submit($text{'index_add'});
local @levels = ( 0, 1, 4, 5 );
push(@levels, 6) if ($raid_mode eq "mdadm");
print &ui_select("level", "linear",
		 [ [ "linear", $text{'linear'} ],
		   map { [ $_, $text{'raid'.$_} ] } @levels ]),"\n";
print &ui_form_end();
}

sub error_exit
{
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("raid", "man", "doc"));
print "<p><b>",@_,"</b><p>\n";
&ui_print_footer("/", $text{'index'});
exit;
}

