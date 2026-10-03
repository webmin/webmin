#!/usr/local/bin/perl
# Show server or domain information

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
# The language table of the system status module is read once below
no warnings 'once';
# The page is the start page, which the browser opens without a Referer
# when the address was typed, as / redirects to it in the single page
# layout. A request with a Referer from another site is still refused.
our $trust_unknown_referers = 2;
require "gray-theme/gray-theme-lib.pl";
require "gray-theme/theme.pl";
&ReadParse();
&load_theme_library();
our ($current_theme, %gconfig, %in);
our %text = &load_language($current_theme);

# Get system info to show
my $sects = get_right_frame_sections();
my @info = &list_combined_system_info($sects, \%in);

# Redirect if needed
my ($redir) = grep { $_->{'type'} eq 'redirect' } @info;
if ($redir) {
	&redirect($redir->{'url'});
	return;
	}

# The body class selects the right frame styles. In the single page layout
# this page shows the menu, even though it uses the popup header.
our $gray_theme_body_class = 'right-frame';
our $gray_theme_menu_page = 1;
&popup_header($text{'left_home'});

# Links from modules become the page actions, with an icon where the
# link is a known one
my @links = grep { $_->{'type'} eq 'link' } @info;
@info = grep { $_->{'type'} ne 'link' } @info;
unshift(@links, { 'link' => 'edit_right.cgi',
	          'desc' => $text{'right_edit'} });
my @actions;
foreach my $l (@links) {
	my $lnk = $l->{'link'};
	$lnk = &get_webprefix().$lnk
		if (&get_webprefix() && $lnk =~ /^\//);
	my $icon = $lnk =~ /edit_right\.cgi/ ? 'gear' :
		   $lnk =~ /recollect\.cgi/ ? 'refresh' :
		   $lnk =~ /licen[cs]e/ ? 'shield' :
		   $lnk =~ /doc/ ? 'book' : undef;
	my $target = !$l->{'target'} ? undef :
		     $l->{'target'} eq 'new' ? '_blank' :
		     $l->{'target'} eq 'window' ? '_top' : undef;
	push(@actions, &ui_tag('a',
		($icon ? &ui_svg_icon($icon, { 'size' => 15 }) : "").
		&ui_tag('span', $l->{'desc'}),
		{ 'class' => 'ui_link page-action',
		  'href' => $lnk,
		  'target' => $target }));
	}

# The system status block supplies the tiles at the top and the line
# under the title. Its rows are found by their labels, in the language
# of that module.
my ($sysinfo) = grep { $_->{'type'} eq 'table' &&
		       $_->{'module'} eq 'system-status' &&
		       $_->{'id'} eq 'sysinfo' } @info;
my @tiles;
my @subtitle;
if ($sysinfo) {
	# The tiles take their rows out of the block; the two subtitle rows
	# are only copied and stay in it
	my $rows = $sysinfo->{'table'};
	my $row = sub {
		my ($key) = @_;
		my $label = $system_status::text{$key};
		return undef if (!$label);
		my ($r) = grep { $_->{'desc'} eq $label } @$rows;
		return $r;
		};
	my $drop = sub {
		my ($r) = @_;
		@$rows = grep { $_ ne $r } @$rows if ($r);
		};

	# Operating system and time under the title
	foreach my $key ('right_os', 'right_time') {
		my $r = $row->($key);
		push(@subtitle, $r->{'value'}) if ($r);
		}

	# CPU load, shown as the one minute average
	my $cpu = $row->('right_cpu');
	if ($cpu && $cpu->{'value'} =~ /^\s*([\d.]+)\s*(.*)$/) {
		push(@tiles, &tile($1, $cpu->{'desc'}, $2));
		$drop->($cpu);
		}

	# Memory and disk, with their bars
	foreach my $key ('right_real', 'right_disk') {
		my $r = $row->($key);
		next if (!$r);
		my ($value, $rest) = $r->{'value'} =~ /^\s*([\d.]+\s*\S+)\s*(.*)$/ ?
			($1, $2) : ($r->{'value'}, "");
		$rest =~ s/^\s*used,?\s*//;
		push(@tiles, &tile($value, $r->{'desc'}, $rest, $r->{'chart'}));
		$drop->($r);
		}

	# Running processes, with the uptime under them
	my $procs = $row->('right_procs');
	if ($procs) {
		my $up = $row->('right_uptime');
		push(@tiles, &tile($procs->{'value'}, $procs->{'desc'},
			$up ? $up->{'desc'}." ".$up->{'value'} : ""));
		$drop->($procs);
		$drop->($up);
		}
	}

# The page area, with its title, subtitle and actions
print &ui_page_assets({ 'nojs' => 1 });
print &ui_page_start({ 'title' => $text{'left_home'},
		       'desc_html' => @subtitle ? join(" &middot; ", @subtitle)
						: undef,
		       'actions' => \@actions,
		       'class' => 'page' });
print &ui_switch_theme_javascript();

# Show notifications first
@info = sort { ($b->{'type'} eq 'warning') <=> ($a->{'type'} eq 'warning') }
	     @info;
my @notices = grep { $_->{'type'} eq 'warning' } @info;
my @blocks = grep { $_->{'type'} ne 'warning' } @info;

foreach my $info (@notices) {
	# A notice, optionally under a heading
	my $w;
	if (ref($info->{'warning'}) eq 'HASH') {
		# Alert HTML supplied by the module
		$w = $info->{'warning'}->{'alert'};
		}
	else {
		# Plain text, wrapped in a notice of the given level
		$w = &ui_alert_box($info->{'warning'},
				      $info->{'level'} || 'warn');
		}
	if ($info->{'desc'}) {
		# Inside a card with the block's heading
		print &section_start($info, 1);
		print $w;
		print &section_end();
		}
	else {
		# On its own
		print $w;
		}
	}

# The tiles, four across, fewer on a narrow frame
if (@tiles) {
	print &ui_grid(\@tiles, { 'cols' => 4, 'class' => 'tiles' });
	}

foreach my $info (@blocks) {
	# A collapsible section
	my $open = defined($info->{'open'}) ? $info->{'open'} : 1;
	print &section_start($info, $open);
	if ($info->{'header'}) {
		# Introductory text above the block's content
		print "<div class='section-note'>",
		      $info->{'header'},"</div>\n";
		}
	if ($info->{'type'} eq 'table') {
		my @rows = @{$info->{'table'}};
		if (@rows && !grep { $_->{'chart'} ||
				      $_->{'value'} !~ /^\s*-?\d+\s*$/ } @rows) {
			# A table of counts, shown as a row of numbers
			print &ui_stats([ map { { 'value' => $_->{'value'},
						   'label' => $_->{'desc'} } }
					      @rows ], { 'min' => '140px' });
			}
		else {
			# Labels and values, two per line. Rows that need
			# a whole line go into lists of their own, so the
			# order is kept.
			my (@lists, $cur);
			foreach my $t (@rows) {
				my $value = $t->{'value'};
				if ($t->{'chart'}) {
					# A bar under the value
					$value .= &make_bar_chart($t->{'chart'});
					}
				my $cols = $t->{'wide'} ? 1 : 2;
				if (!$cur || $cur->[0] != $cols) {
					# A new list starts when the column
					# count changes
					$cur = [ $cols, [ ] ];
					push(@lists, $cur);
					}
				# Labels are HTML too, such as status icons
				push(@{$cur->[1]}, { 'label_html' => $t->{'desc'},
						     'value_html' => $value });
				}
			foreach my $l (@lists) {
				print &ui_dl($l->[1], { 'cols' => $l->[0] });
				}
			}
		}
	elsif ($info->{'type'} eq 'chart' || $info->{'type'} eq 'usage') {
		# A bordered table of bars, one per row. Without
		# headings, the table has only its rows.
		my $rows = $info->{'chart'} || $info->{'usage'};
		if ($info->{'titles'}) {
			# With headings, a normal table of columns
			print &ui_columns_start($info->{'titles'}, 100);
			}
		else {
			# Without headings, just the rows in a card
			print "<table class='wrapper' width='100%'>",
			      "<tr><td>\n";
			print "<table class='ui_table ui_columns' ",
			      "width='100%'><tbody>\n";
			}
		foreach my $t (@$rows) {
			print &ui_columns_row([
				$t->{'desc'},
				&make_bar_chart($t->{'chart'}),
				$t->{'value'},
				], [ "width='30%'", "width='40%'", "" ]);
			}
		if ($info->{'titles'}) {
			print &ui_columns_end();
			}
		else {
			print "</tbody></table></td></tr></table>\n";
			}
		}
	elsif ($info->{'type'} eq 'html') {
		# A chunk of HTML
		print $info->{'html'};
		}
	print &section_end();
	}

print &ui_page_end();
&popup_footer();

# tile(value, label, desc, [&chart])
# Returns a card with one large figure, its label and a line under it,
# and a bar when a chart is given. The figure and the line are HTML from
# the modules, such as a linked count.
sub tile
{
my ($value, $label, $desc, $chart) = @_;
my $body = &ui_stat({ 'value_html' => $value,
		      'label_html' => $label,
		      'desc_html' => $desc });
$body .= &make_bar_chart($chart) if ($chart);
return &ui_card({ 'body' => $body, 'class' => 'tile' });
}

# section_start(&info, open)
# Returns HTML for the start of a collapsible card for a system info block
sub section_start
{
my ($info, $open) = @_;
my %attrs = ( 'class' => 'section',
	      'data-name' => $info->{'module'}.$info->{'id'} );
$attrs{'open'} = undef if ($open);
return &ui_tag_start('details', \%attrs)."\n".
       &ui_tag('summary', &ui_tag('span', $info->{'desc'}))."\n".
       &ui_tag_start('div', { 'class' => 'section-body' })."\n";
}

# section_end()
# Returns HTML for the end of a card started by section_start
sub section_end
{
return &ui_tag_end('div').&ui_tag_end('details')."\n";
}

# make_bar_chart(&chart)
# Returns a bar for a chart of [ total, used, [also-used] ]. The used
# amount fills the bar in the accent color, turning amber above 75% and
# red above 90% of the total; the extra amount follows in a lighter tint.
sub make_bar_chart
{
my ($c) = @_;
my ($total, $used, $extra) = @$c;
$used ||= 0;
$extra ||= 0;
$total = $used + $extra if (!$total || $total < $used + $extra);
return "" if (!$total);
my $pct = $used * 100 / $total;
my $state = $pct >= 90 ? 'danger' : $pct >= 75 ? 'warning' : 'info';
my @segments = ( { 'pct' => $pct, 'state' => $state } );
if ($extra) {
	# The second segment, drawn in the neutral tint
	push(@segments, { 'pct' => $extra * 100 / $total,
			  'state' => 'neutral' });
	}
return &ui_progress(undef, { 'segments' => \@segments, 'small' => 1 });
}
