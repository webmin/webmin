#!/usr/local/bin/perl
# Update the times for a Webmin cron action

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'webmincron_err'});

if (!&foreign_check("webmincron")) {
	&ui_print_endpage($text{'webmincron_emodule'});
	}
&foreign_require("webmincron");
my @wcrons = &webmincron::list_webmin_crons();
my ($wcron) = grep { $_->{'id'} eq $in{'id'} } @wcrons;
$wcron || &error($text{'webmincron_egone'});

if ($in{'delete'}) {
	# Just delete the job
	&webmincron::delete_webmin_cron($wcron);
	&webmin_log("onedelete", "webmincron", $wcron->{'mod'}, $wcron);
	}
else {
	# Validate new time
	if ($in{'whenmode'} == 0) {
		$in{'interval'} =~ /^\d+$/ && $in{'interval'} > 0 ||
			&error($text{'webmincron_einterval'});
		$wcron->{'interval'} = $in{'interval'};
		}
	else {
		&webmincron::parse_times_input($wcron, \%in);
		delete($wcron->{'interval'});
		}

	# Save cron job
	&webmincron::save_webmin_cron($wcron);
	&webmin_log("save", "webmincron", $wcron->{'mod'}, $wcron);
	}

&redirect("edit_webmincron.cgi");
