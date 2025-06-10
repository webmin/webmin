#!/usr/local/bin/perl
# list_features.cgi
# Display a list of all sendmail features from the M4 file

require './sendmail-lib.pl';
require './features-lib.pl';

$features_access || &error($text{'features_ecannot'});
&ui_print_header(undef, $text{'features_title'}, "");

@features = &list_features() if (-r $config{'sendmail_mc'} &&
				 -r "$config{'sendmail_features'}/feature");
if (@features) {
	# Show table of features
	print &text('features_desc', "<tt>$config{'sendmail_mc'}</tt>",
		    "<tt>$config{'sendmail_cf'}</tt>"),"<p>\n";
	print "<form action=edit_feature.cgi>\n";
	print "<input type=hidden name=new value=1>\n";
	print "<table cellpadding=0 cellspacing=0 width=100%>\n";
	print "<tr $tb> <td><b>$text{'features_type'}</b></td>\n";
	print "<td><b>$text{'features_value'}</b></td>\n";
	print "<td><b>$text{'features_move'}</b></td> </tr>\n";
	local $i = 0;
	foreach $f (@features) {
		print "<tr $cb>\n";
		print "<td><a href='edit_feature.cgi?idx=$f->{'index'}'>";
		print "<b>" if ($f->{'type'});
		print $text{"features_type".$f->{'type'}};
		print "</b>" if ($f->{'type'});
		print "</a></td>\n";
		print "<td><tt>",$f->{'text'} ? &html_escape($f->{'text'})
					      : "<br>","</tt></td>\n";
		print "</tt></td>\n";
		print "<td>";
		if ($i == @features-1) {
			print "<img src=images/gap.gif>";
			}
		else {
			print "<a href='move.cgi?idx=$i&down=1'>",
			      "<img border=0 src=images/down.gif></a>";
			}
		if ($i == 0) {
			print "<img src=images/gap.gif>";
			}
		else {
			print "<a href='move.cgi?idx=$i&up=1'>",
			      "<img border=0 src=images/up.gif></a>";
			}
		print "</td>\n";
		print "</tr>\n";
		$i++;
		}
	print "</table>\n";
	print "<table width=100%><tr><td>\n";
	print "<input type=submit value='$text{'features_add'}'>\n";
	print "<select name=type>\n";
	foreach $i (0, 1, 2, 4, 5) {
		print "<option value=$i>",$text{'features_type'.$i},"</option>\n";
		}
	print "</select></td>\n";
	print "<td align=right><input type=submit name=manual ",
	      "value='$text{'features_manual'}'></td>\n";
	print "</tr></table></form>\n";

	# Show button to rebuild sendmail.cf
	print &ui_hr();
	print "<form action=build.cgi>\n";
	print "<table width=100%><tr>\n";
	print "<td><input type=submit value='$text{'features_build'}'></td>\n";
	print "<td>",&text('features_buildmsg', "<tt>$config{'sendmail_cf'}</tt>"),
	      "</td>\n";
	print "</tr></table>\n";
	}
else {
	# Features file is not setup yet ..
	if (!$config{'sendmail_mc'} || !$config{'sendmail_features'}) {
		print "<p>",&text('features_econfig',
				  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
		}
	elsif (!-r $config{'sendmail_mc'}) {
		print "<p>",&text('features_emc', "@{[&get_webprefix()]}/config.cgi?$module_name",
				  "<tt>$config{'sendmail_mc'}</tt>"),"<p>\n";
		}
	elsif (!-r "$config{'sendmail_features'}/feature") {
		print "<p>",&text('features_efeatures', "@{[&get_webprefix()]}/config.cgi?$module_name",
				  "<tt>$config{'sendmail_features'}</tt>"),"<p>\n";
		}
	}

&ui_print_footer("", $text{'index_return'});

