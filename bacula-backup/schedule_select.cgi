#!/usr/local/bin/perl
# Convert inputs into a schedule string, and update the original field

require './bacula-backup-lib.pl';
&ReadParse();
&error_setup($text{'chooser_err'});

# Validate inputs and make the object
$sched = { };
foreach $f ("months", "weekdays", "weekdaynums", "days") {
	if ($in{$f."_all"}) {
		$sched->{$f."_all"} = 1;
		}
	else {
		defined($in{$f}) || &error($text{'chooser_e'.$f});
		$sched->{$f} = [ split(/\0/, $in{$f}) ];
		}
	}
$in{'hour'} =~ /^\d+$/ && $in{'hour'} >= 0 && $in{'hour'} < 24 ||
	&error($text{'chooser_ehour'});
$sched->{'hour'} = $in{'hour'};
$in{'minute'} =~ /^\d+$/ && $in{'minute'} >= 0 && $in{'minute'} < 60 ||
	&error($text{'chooser_eminute'});
$sched->{'minute'} = $in{'minute'};

# Update the original field
$str = &join_schedule($sched);
&popup_header($text{'chooser_title'});

print <<EOF;
<script>
top.opener.ifield.value = "$str";
window.close();
</script>
EOF

&popup_footer();

