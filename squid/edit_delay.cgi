#!/usr/local/bin/perl
# edit_delay.cgi
# Displays a list of existing delay pools

require './squid-lib.pl';
$access{'delay'} || &error($text{'delay_ecannot'});
&ui_print_header(undef, $text{'delay_title'}, "", "edit_delay", 0, 0, 0, &restart_button());
$conf = &get_config();

# Display all known delay pools
$pools = &find_value("delay_pools", $conf);
@links = ( &select_all_link("d"),
	   &select_invert_link("d"),
	   "<a href='edit_pool.cgi?new=1'>$text{'delay_add'}</a>" );
if ($pools) {
	@pools = sort { $a->{'values'}->[0] <=> $b->{'values'}->[0] }
		      &find_config("delay_class", $conf);
	@params = &find_config("delay_parameters", $conf);
	print &ui_form_start("delete_pools.cgi", "post");
	print &ui_links_row(\@links);
	@tds = ( "width=5" );
	print &ui_columns_start([ "",
				  $text{'delay_num'},
				  $text{'delay_class'},
				  $text{'delay_agg'},
				  $text{'delay_ind'},
				  $text{'delay_net'},
				  $squid_version >= 3 ? (
					$text{'delay_user'},
					$text{'delay_tag'} ) : ( ),
				], 100, 0, \@tds);
	foreach $p (@pools) {
		local ($pr) = grep { $_->{'values'}->[0] ==
				     $p->{'values'}->[0] } @params;
		local @cols;
		push(@cols, "<a href='edit_pool.cgi?idx=$p->{'values'}->[0]'>".
			    "$p->{'values'}->[0]</a>");
		push(@cols, $text{"delay_class_$p->{'values'}->[1]"});
		if ($p->{'values'}->[1] == 5) {
			push(@cols, "", "", "", "");
			push(@cols, &pool_param($pr->{'values'}->[1]));
			}
		else {
			push(@cols, &pool_param($pr->{'values'}->[1]));
			if ($p->{'values'}->[1] == 2) {
				push(@cols, &pool_param($pr->{'values'}->[2]));
				push(@cols, "");
				}
			else {
				push(@cols, &pool_param($pr->{'values'}->[3]));
				push(@cols, &pool_param($pr->{'values'}->[2]));
				}
			if ($squid_version >= 3) {
				if ($p->{'values'}->[1] == 4) {
					push(@cols, &pool_param(
						$pr->{'values'}->[4]));
					}
				else {
					push(@cols, "");
					}
				push(@cols, "");
				}
			}
		print &ui_checked_columns_row(\@cols, \@tds,
					      "d", $p->{'values'}->[0]);
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'delay_delete'} ] ]);
	}
else {
	print "<b>$text{'delay_none'}</b><p>\n";
	print &ui_links_row([ $links[2] ]);
	}

print "<form action=save_delay.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'delay_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
print &opt_input($text{'delay_initial'}, "delay_initial_bucket_level", $conf,
		 $text{'default'}, 4, "%");
print "<td colspan=2 width=50%></td>\n";
print "</tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'eicp_return'});

# pool_param(param)
sub pool_param
{
if ($_[0] =~ /^([0-9\-]+)\/([0-9\-]+)$/) {
	return $1 == -1 ? $text{'delay_unlimited'} :
		&text('delay_param', "$1", "$2");
	}
else {
	return $_[0];	# huh?
	}
}

