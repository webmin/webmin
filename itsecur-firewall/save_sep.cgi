#!/usr/bin/perl
# Create, update or delete a rules section separator

require './itsecur-lib.pl';
&can_edit_error("rules");
&ReadParse();
@rules = &list_rules();
if (!$in{'new'}) {
	$rule = $rules[$in{'idx'}];
	}
&lock_itsecur_files();

if ($in{'delete'}) {
	# Just take out rule
	splice(@rules, $in{'idx'}, 1);
	}
else {
	# Validate and store inputs
	&error_setup($text{'sep_err'});
	$in{'desc'} || &error($text{'sep_edesc'});
	$rule->{'desc'} = $in{'desc'};
	$rule->{'sep'} = 1;

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
&save_rules(@rules);
&unlock_itsecur_files();
&remote_webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "update",
	    "sep", $rule->{'index'}+1, $rule);
&redirect("list_rules.cgi");

