#!/usr/local/bin/perl
# Show server or domain information

use strict;
use warnings;
require "gray-theme/gray-theme-lib.pl";
require "gray-theme/theme.pl";
&ReadParse();
&load_theme_library();
our ($current_theme, %gconfig, %in);
our %text = &load_language($current_theme);
my $bar_width = 500;

# Get system info to show
my $sects = get_right_frame_sections();
my @info = &list_combined_system_info($sects, \%in);

# Redirect if needed
my ($redir) = grep { $_->{'type'} eq 'redirect' } @info;
if ($redir) {
	&redirect($redir->{'url'});
	return;
	}

my $prehead = defined(&WebminCore::theme_prehead) ?
		&capture_function_output(\&WebminCore::theme_prehead) : "";
&popup_header(undef, $prehead);

# Links appear at the top of the page
my @links = grep { $_->{'type'} eq 'link' } @info;
@info = grep { $_->{'type'} ne 'link' } @info;
unshift(@links, { 'link' => 'edit_right.cgi',
	          'desc' => $text{'right_edit'} });
my @linkshtml = map {
	my $lnk = $_->{'link'};
	$lnk = &theme_get_webprefix_safe().$lnk
		if (&theme_get_webprefix_safe() && $lnk =~ /^\//);
	&ui_link($lnk, $_->{'desc'}, undef,
		 !$_->{'target'} ? '' :
	         $_->{'target'} eq 'new' ? 'target=_blank' :
		 $_->{'target'} eq 'window' ? 'target=_top' : '') } @links;
print "<div align=right>\n";
print &ui_links_row(\@linkshtml);
print "</div>\n";

# Show notifications first
@info = sort { ($b->{'type'} eq 'warning') <=> ($a->{'type'} eq 'warning') }
	     @info;

foreach my $info (@info) {
	if ($info->{'type'} eq 'warning') {
		my $w;
		if (ref($info->{'warning'}) eq 'HASH') {
			$w = $info->{'warning'}->{'alert'};
			}
		else {
			$w = &ui_alert_box($info->{'warning'},
					      $info->{'level'} || 'warn');
			}
		if ($info->{'desc'}) {
			print &ui_table_start($info->{'desc'}, "width=100%");
			print &ui_table_row(undef, $w, 4);
			print &ui_table_end();
			}
		else {
			print $w;
			}
		}
	else {
                my $open = defined($info->{'open'}) ? $info->{'open'} : 1;
                print &ui_hidden_table_start($info->{'desc'}, "width=100%", 4,
                                             $info->{'module'}.$info->{'id'},
                                             $open);
		if ($info->{'type'} eq 'table') {
			# A table of various labels and values
			if ($info->{'header'}) {
				print &ui_table_row(
					undef, $info->{'header'}, 4);
				}
			foreach my $t (@{$info->{'table'}}) {
				my $chart = "";
				if ($t->{'chart'}) {
					$chart = &make_bar_chart(
							$t->{'chart'});
					$chart = "<br>".$chart;
					}
				print &ui_table_row($t->{'desc'},
				    $t->{'value'}.$chart,
				    $t->{'wide'} || $t->{'chart'} ? 3 : 1);
				}
			}
		elsif ($info->{'type'} eq 'chart') {
			# A table of graphs
			my $ctable;
			if ($info->{'header'}) {
				$ctable .= $info->{'header'}."<br>\n";
				}
			$ctable .= &ui_columns_start($info->{'titles'});
			foreach my $t (@{$info->{'chart'}}) {
				$ctable .= &ui_columns_row([
					$t->{'desc'},
					&make_bar_chart($t->{'chart'}),
					$t->{'value'},
					]);
				}
			$ctable .= &ui_columns_end();
			print &ui_table_row(undef, $ctable, 4);
			}
		elsif ($info->{'type'} eq 'html') {
			# A chunk of HTML
			print &ui_table_row(undef, $info->{'html'}, 4);
			}
                print &ui_hidden_table_end();
		}
	}

print "</center>\n";
&popup_footer();

# bar_chart_three(total, used1, used2, used3)
# Returns HTML for a bar chart of three values, stacked
sub bar_chart_three
{
my ($total, $used1, $used2, $used3) = @_;
$used1 ||= 0;
$used2 ||= 0;
$used3 ||= 0;
my $rv;
my $w1 = int($bar_width*$used1/$total)+1;
my $w2 = int($bar_width*$used2/$total);
my $w3 = int($bar_width*$used3/$total);
$rv .= sprintf "<img src=images/red.gif width=%s height=10>", $w1;
$rv .= sprintf "<img src=images/purple.gif width=%s height=10>", $w2;
$rv .= sprintf "<img src=images/blue.gif width=%s height=10>", $w3;
$rv .= sprintf "<img src=images/grey.gif width=%s height=10>",
	$bar_width - $w1 - $w2 - $w3;
return $rv;
}

sub make_bar_chart
{
my ($c) = @_;
my @c = @$c;
$c[1] ||= 0;
$c[2] ||= 0;
if (@c == 2) {
	return &bar_chart_three(
		$c[0], $c[1], 0, $c[0]-$c[1]);
	}
else {
	return &bar_chart_three(
		$c[0], $c[1], $c[2],
		$c[0]-$c[1]-$c[2]);
	}
}

