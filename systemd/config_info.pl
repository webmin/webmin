use strict;
use warnings;

require './systemd-lib.pl'; ## no critic

our (%in, %text);

# show_visible_tabs(value)
# Returns checkbox controls for choosing which index tabs are visible.
sub show_visible_tabs
{
my ($value) = @_;
my %enabled = map { $_, 1 } split(/\s*,\s*/, $value || default_visible_tabs());
my @fields;
foreach my $tab (get_index_tab_ids()) {
	my $label = $text{'systemd_tab_'.$tab} || ucfirst($tab);
	push(@fields, ui_checkbox(
		"visible_tabs", $tab, $label, $enabled{$tab}));
	}
return join(" ", @fields);
}

# parse_visible_tabs(value)
# Returns selected tab IDs, and rejects saving with every tab hidden.
sub parse_visible_tabs
{
my @tabs = split(/\0/, $in{'visible_tabs'} || "");
my %valid = map { $_, 1 } get_index_tab_ids();
@tabs = grep { $valid{$_} } @tabs;
@tabs || error($text{'systemd_evisibletabs'});
return join(",", @tabs);
}

1;
