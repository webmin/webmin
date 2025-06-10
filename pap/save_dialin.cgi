#!/usr/local/bin/perl
# save_dialin.cgi
# Create, update or delete a caller ID number

require './pap-lib.pl';
$access{'dialin'} || &error($text{'dialin_ecannot'});
&ReadParse();
@dialin = &parse_dialin_config();
$dialin = $dialin[$in{'idx'}] if (!$in{'new'});

&lock_file($config{'dialin_config'});
if ($in{'delete'}) {
	# Delete the number
	&delete_dialin($dialin, \@dialin);
	}
else {
	# Validate inputs
	&error_setup($text{'dialin_err'});
	$in{'mode'} != 2 || $in{'number'} =~ /^\d+$/ ||
		&error($text{'dialin_enumber'});

	$dialin->{'number'} = $in{'mode'} == 0 ? 'all' :
			      $in{'mode'} == 1 ? 'none' : $in{'number'};
	$dialin->{'not'} = !$in{'allow'};
	if ($in{'new'}) {
		# Add a new number
		&create_dialin($dialin, \@dialin);
		}
	else {
		# Update an existing number
		&modify_dialin($dialin, \@dialin);
		}
	}
&unlock_file($config{'dialin_config'});
&webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "modify",
	    "dialin", $dialin->{'number'}, $dialin);
&redirect("list_dialin.cgi");

