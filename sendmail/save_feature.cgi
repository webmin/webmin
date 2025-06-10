#!/usr/local/bin/perl
# save_feature.cgi
# Add a new line to the M4 file

require './sendmail-lib.pl';
require './features-lib.pl';
&ReadParse();
$features_access || &error($text{'features_ecannot'});
&error_setup($text{'feature_err'});

@features = &list_features();
if ($in{'new'}) {
	$feature = { 'type' => $in{'type'} };
	}
else {
	$feature = $features[$in{'idx'}];
	}

&lock_file($config{'sendmail_mc'});
if ($in{'delete'}) {
	# Just delete this entry
	&delete_feature($feature);
	}
else {
	# Validate and store inputs
	if ($feature->{'type'} == 0) {
		$feature->{'text'} = $in{'text'};
		}
	elsif ($feature->{'type'} == 1) {
		#local ($same) = grep { $_->{'type'} == 1 &&
		#		       $_->{'name'} eq $in{'name'} } @features;
		#$same && ($in{'new'} || $feature->{'name'} ne $in{'name'}) &&
		#	&error(&text('feature_efeat', "<tt>$in{'name'}</tt>"));
		$feature->{'name'} = $in{'name'};
		local @v;
		for($i=0; defined($in{"value_$i"}); $i++) {
			push(@v, $in{"value_$i"});
			}
		while($v[$#v] eq '' && @v) { pop(@v); }
		$feature->{'values'} = \@v;
		}
	elsif ($feature->{'type'} == 2 || $feature->{'type'} == 3) {
		local ($same) = grep { ($_->{'type'} == 2 || $_->{'type'} == 3) &&
				       $_->{'name'} eq $in{'name'} } @features;
		$same && ($in{'new'} || $feature->{'name'} ne $in{'name'}) &&
			&error(&text('feature_edef', "<tt>$in{'name'}</tt>"));
		$feature->{'name'} = $in{'name'};
		if ($in{'undef'}) {
			$feature->{'type'} = 3;
			}
		else {
			$feature->{'type'} = 2;
			$feature->{'value'} = $in{'value'};
			}
		}
	elsif ($feature->{'type'} == 4) {
		local ($same) = grep { $_->{'type'} == 4 &&
				       $_->{'mailer'} eq $in{'mailer'} } @features;
		$same && ($in{'new'} || $feature->{'mailer'} ne $in{'mailer'}) &&
			&error(&text('feature_emailer', "<tt>$in{'mailer'}</tt>"));
		$feature->{'mailer'} = $in{'mailer'};
		}
	elsif ($feature->{'type'} == 5) {
		local ($same) = grep { $_->{'type'} == 5 } @features;
		$same && $in{'new'} &&
			&error(&text('feature_eostype', "<tt>$in{'ostype'}</tt>"));
		$feature->{'ostype'} = $in{'ostype'};
		}

	# Save or create the entry
	if ($in{'new'}) {
		&create_feature($feature);
		}
	else {
		&modify_feature($feature);
		}
	}

&unlock_file($config{'sendmail_mc'});
&webmin_log($in{'new'} ? 'create' : $in{'delete'} ? 'delete' : 'modify',
	    "feature", undef, $feature);
&redirect("list_features.cgi");

