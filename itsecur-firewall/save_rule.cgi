#!/usr/bin/perl
# save_rule.cgi
# Create, update or delete a firewall rule

require './itsecur-lib.pl';
&can_edit_error("rules");
&ReadParse();
@rules = &list_rules();
@groups = &list_groups();
if (!$in{'new'}) {
	$rule = $rules[$in{'idx'}];
	}
&lock_itsecur_files();

if ($config{'rusure'} && !$in{'confirm'} && !$in{'new'}) {
	# Ask for confirmation before making this change
	&header($text{'rule_title2'}, "",
		undef, undef, undef, undef, &apply_button());
	$rule = $rules[$in{'idx'}];
	print "<hr>\n";

	print "<form action=save_rule.cgi>\n";
	print "<center>",&text($in{'delete'} ? 'rule_rusured'
					     : 'rule_rusures'),"<p>\n";
	foreach $i (keys %in) {
		foreach $v (split(/\0/, $in{$i})) {
			print "<input type=hidden name=$i value='",
				&html_escape($v),"'>\n";
			}
		}
	print "<input type=submit name=confirm value='$text{'rule_goahead'}'>\n";
	print "</center></form>\n";

	print "<hr>\n";
	&footer("list_rules.cgi", $text{'rules_return'});
	exit;
	}

if ($in{'delete'}) {
	# Just take out rule
	splice(@rules, $in{'idx'}, 1);
	}
else {
	# Validate and store inputs
	&error_setup($text{'rule_err'});
	$rule->{'desc'} = $in{'desc'} || "*";
	foreach $s ('source', 'dest') {
		if ($in{"${s}_mode"} == 0) {
			$rule->{$s} = "*";
			}
		elsif ($in{"${s}_mode"} == 1) {
			&valid_host($in{"${s}_host"}) ||
			    &error($text{"rule_e${s}"});
			if ($in{"${s}_resolv"}) {
				local $rs = &to_ipaddress($in{"${s}_host"});
				$in{"${s}_host"} = $rs if ($rs);
				}
			if ($in{"${s}_name"}) {
				# Add a group for this network/host
				$in{"${s}_name"} =~ /^\S+$/ ||
					&error($text{'rule_ename'});
				$rule->{$s} = "@".$in{"${s}_name"};
				local @mems = ( $in{"${s}_host"} );
				push(@groups, { 'name' => $in{"${s}_name"},
						'members' => \@mems });
				}
			else {
				$rule->{$s} = $in{"${s}_host"};
				}
			}
		elsif ($in{"${s}_mode"} == 2) {
			$rule->{$s} = join(" ", map { '@'.$_ }
					   split(/\0/, $in{"${s}_group"}));
			$rule->{$s} || &error($text{'rule_egroups'});
			}
		elsif ($in{"${s}_mode"} == 3) {
			$rule->{$s} = '%'.$in{"${s}_iface"};
			}
		$rule->{$s} = "!".$rule->{$s} if ($in{"${s}_not"});
		}
	if ($in{"service_mode"} == 0) {
		$rule->{'service'} = "*";
		}
	else {
		$rule->{'service'} = join(",", split(/\0/, $in{"service"}));
		$rule->{'service'} || &error($text{'rule_eservices'});
		}
	$rule->{'service'} = "!".$rule->{'service'} if ($in{'snot'});
	$rule->{'action'} = $in{'action'};
	$rule->{'log'} = int($in{'log'});
	$rule->{'time'} = $in{'time_def'} ? "*" : $in{'time'};
	$rule->{'enabled'} = $in{'enabled'};

	if ($in{'new'}) {
		# Add to list at chosen position
		if ($in{'pos'} == -1) {
			push(@rules, $rule);
			}
		else {
			splice(@rules, $in{'pos'}, 0, $rule);
			}
		}
	else {
		# Maybe change position
		foreach $r (grep { $_ ne $rule } @rules) {
			if ($r->{'index'} == $in{'pos'}) {
				push(@newrules, $rule);
				}
			push(@newrules, $r);
			}
		push(@newrules, $rule) if ($in{'pos'} == -1);
		@rules = @newrules;
		}
	}

# Save rules list
&automatic_backup();
&save_rules(@rules);
&save_groups(@groups);
&unlock_itsecur_files();
&remote_webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "update",
	    "rule", $rule->{'index'}+1, $rule);
&redirect("list_rules.cgi");

