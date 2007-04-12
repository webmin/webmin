#!/usr/local/bin/perl
# edit_policy.cgi
# Display entries from a policy file for editing

require './ipsec-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'policy_desc_'.$in{'policy'}} ||
        &text('policy_desc', $in{'policy'}), "");

# Show explanation of this policy
print $text{'policy_longdesc_'.$in{'policy'}} ||
      &text('policy_longdesc', $in{'policy'}),"<p>\n";
print "<form action=save_policy.cgi method=post>\n";
print "<input type=hidden name=policy value='$in{'policy'}'>\n";

@policies = &read_policy($in{'policy'});
$mode = !@policies ? 0 :
	@policies == 1 && $policies[0] eq "0.0.0.0/0" ? 1 : 2;
foreach $m (0 .. 2) {
	printf "<input type=radio name=mode value=%s %s> %s\n",
		$m, $mode == $m ? "checked" : "", $text{'policy_mode'.$m};
	}
print "<br>\n";

# Show a table of networks
print "<table border>\n";
print "<tr $tb> <td><b>$text{'policy_net'}</b></td> ",
      "<td><b>$text{'policy_mask'}</b></td> </tr>\n";
$i = 0;
foreach $p ($mode == 2 ? @policies : ( ), "", "") {
	local ($n, $m) = split(/\//, $p);
	print "<tr $cb>\n";
	print "<td><input name=net_$i size=20 value='$n'></td>\n";
	print "<td><input name=mask_$i size=5 value='$m'></td>\n";
	print "</tr>\n";
	$i++;
	}
print "</table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

