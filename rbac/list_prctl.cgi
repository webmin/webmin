#!/usr/local/bin/perl
# Show active resource limits

require './rbac-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'prctl_title'}, "", "prctl", 0, 0, 0,
		 &help_search_link("prctl", "man"));

# Show selection form
print &ui_form_start("list_prctl.cgi", "get");
print "<table>\n";
print "<tr> <td valign=top rowspan=4>",&ui_submit($text{'prctl_ok'}),"</td>\n";

# For a process
print "<td>",&ui_oneradio("mode", 0, $text{'prctl_mode0'},
			  $in{'mode'} == 0),"</td>\n";
print "<td>",&ui_textbox("pid", $in{'pid'}, 10),"</td> </tr>\n";

# For a project
print "<td>",&ui_oneradio("mode", 1, $text{'prctl_mode1'},
			  $in{'mode'} == 1),"</td>\n";
print "<td>",&project_input("project", $in{'project'}),"</td> </tr>\n";

# For a zone
if (&foreign_check("zones")) {
	&foreign_require("zones", "zones-lib.pl");
	@zones = &zones::list_zones();
	$nozones = 1 if (!@zones);
	}
if (!$nozones) {
	print "<td>",&ui_oneradio("mode", 2, $text{'prctl_mode2'},
				  $in{'mode'} == 2),"</td>\n";
	if (@zones) {
		print "<td>",&ui_select("zone", $in{'zone'},
			[ map { [ $_->{'name'} ] } &zones::list_zones() ]),
			"</td> </tr>\n";
		}
	else {
		print "<td>",&ui_textbox("zone", $in{'zone'}, 20),
		      "</td> </tr>\n";
		}
	}

# For a task
print "<td>",&ui_oneradio("mode", 3, $text{'prctl_mode3'},
			  $in{'mode'} == 3),"</td>\n";
print "<td>",&ui_textbox("task", $in{'task'}, 10),"</td> </tr>\n";

print "</table>\n";
print &ui_form_end();

if (defined($in{'mode'})) {
	# Show the results (if there were no errors in the input)
	if ($in{'mode'} == 0) {
		$err = $text{'prctl_epid'} if ($in{'pid'} !~ /^\d+$/);
		$id = $in{'pid'};
		$type = "process";
		}
	elsif ($in{'mode'} == 1) {
		$id = $in{'project'};
		$type = "project";
		}
	elsif ($in{'mode'} == 2) {
		$id = $in{'zone'};
		$type = "zone";
		}
	elsif ($in{'mode'} == 3) {
		$err = $text{'prctl_etask'} if ($in{'task'} !~ /^\d+$/);
		$id = $in{'task'};
		$type = "task";
		}
	if ($err) {
		print "<b>$err</b><p>\n";
		}
	elsif (@res = &list_resource_controls($type, $id)) {
		# Found some .. show them
		print &ui_columns_start([
			$text{'prctl_res'},
			$text{'prctl_priv'},
			$text{'prctl_limit'},
			$text{'prctl_action'} ]);
		foreach $r (@res) {
			print &ui_columns_row([
				$r->{'res'},
				$text{'project_'.$r->{'priv'}} || $r->{'priv'},
				$r->{'limit'},
				$r->{'action'} =~ /^signal=(\S+)$/ ?
					&text('prctl_signal', "$1") :
				$text{'project_'.$r->{'action'}} ||
					$r->{'action'},
				]);
			}
		print &ui_columns_end();
		}
	else {
		print "<b>$text{'prctl_none'}</b><p>\n";
		}
	}

&ui_print_footer("", $text{"index_return"});

