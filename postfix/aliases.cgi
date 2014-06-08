#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
# 
# Manages aliases for Postfix
#
# << Here are all options seen in Postfix sample-aliases.cf >>


require './postfix-lib.pl';

$access{'aliases'} || &error($text{'aliases_ecannot'});
&ui_print_header(undef, $text{'aliases_title'}, "", "aliases");



# alias general options
print "$text{'aliases_warning'}<p>\n";
print &ui_form_start("save_opts_aliases.cgi");
print &ui_table_start($text{'aliasopts_title'}, "width=100%", 2);

# Aliases file
&option_mapfield("alias_maps", 60);

# Aliases DB?
&option_mapfield("alias_database", 60);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'opts_save'} ] ]);
print &ui_hr();


# double-table displaying all aliases
my @aliases = &list_postfix_aliases();
if ($config{'sort_mode'} == 1) {
	@aliases = sort { lc($a->{'name'}) cmp lc($b->{'name'}) }
			@aliases;
	}

# find a good place to split
$lines = 0;
for($i=0; $i<@aliases; $i++) {
	$aline[$i] = $lines;
	$al = scalar(@{$aliases[$i]->{'values'}});
	$lines += ($al ? $al : 1);
	}
$midline = int(($lines+1) / 2);
for($mid=0; $mid<@aliases && $aline[$mid] < $midline; $mid++) { }

# render tables
print &ui_form_start("delete_aliases.cgi", "post");
@links = ( &select_all_link("d", 1),
	   &select_invert_link("d", 1),
	   &ui_link("edit_alias.cgi?new=1",$text{'new_alias'}),
	 );
print &ui_links_row(\@links);
if ($config{'columns'} == 2) {
	@grid = ( );
	push(@grid, &aliases_table(@aliases[0..$mid-1]));
	if ($mid < @aliases) {
		push(@grid, &aliases_table(@aliases[$mid..$#aliases]));
		}
	print &ui_grid_table(\@grid, 2, 100, [ "width=50%", "width=50%" ]);
	}
else {
	print &aliases_table(@aliases);
	}
print &ui_links_row(\@links);
print &ui_form_end([ [ "delete", $text{'aliases_delete'} ] ]);

# manual edit button
if ($access{'manual'} && &can_map_manual($_[0])) {
    print &ui_hr();
    print &ui_buttons_start();
    print &ui_buttons_row("edit_manual.cgi", $text{'new_manual'},
			  $text{'new_manualmsg'},
			  &ui_hidden("map_name", "alias_maps"));
    print &ui_buttons_end();
    }

&ui_print_footer("", $text{'index_return'});

# aliases_table(&alias, ...)
# Returns a table of aliases
sub aliases_table
{
my @table;
foreach my $a (@_) {
	my @cols;
	push(@cols, { 'type' => 'checkbox', 'name' => 'd',
		      'value' => $a->{'name'} });
	push(@cols, "<a href=\"edit_alias.cgi?num=$a->{'num'}\">".
	      ($a->{'enabled'} ? "" : "<i>").&html_escape($a->{'name'}).
	      ($a->{'enabled'} ? "" : "</i>")."</a>");
	local $vstr;
	foreach $v (@{$a->{'values'}}) {
		($anum, $astr) = &alias_type($v);
		$vstr .= &text("aliases_type$anum",
			    "<tt>".&html_escape($astr)."</tt>")."<br>\n";
		}
	$vstr ||= "<i>$text{'aliases_none'}</i>\n";
	push(@cols, $vstr);
	push(@cols, &html_escape($a->{'cmt'})) if ($config{'show_cmts'});
	push(@table, \@cols);
	}

return &ui_columns_table(
	[ '', $text{'aliases_addr'}, $text{'aliases_to'},
	  $config{'show_cmts'} ? ( $text{'mapping_cmt'} ) : ( ) ],
	100, \@table);
}

