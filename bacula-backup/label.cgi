#!/usr/local/bin/perl
# Actually label a volume

require './bacula-backup-lib.pl';
&ReadParse();

# Validate inputs
&error_setup($text{'label_err'});
$in{'label'} =~ /\S/ || &error($text{'label_elabel'});

# Do it
&ui_print_unbuffered_header(undef,  $text{'label_title'}, "");

print "<b>",&text('label_run', "<tt>$in{'storage'}</tt>", $in{'label'}),"</b>\n";
print "<pre>";
$h = &open_console();

# Do the label
&sysprint($h->{'infh'}, "label storage=$in{'storage'}\n");
$rv = &wait_for($h->{'outfh'}, 'name:',
			       'not found');
print $wait_for_input;
if ($rv == 1) {
	&job_error($text{'label_estorage'});
	}
&sysprint($h->{'infh'}, $in{'label'}."\n");
$rv = &wait_for($h->{'outfh'}, 'already exists',
			       'Connecting to Storage daemon',
			       '((.*\n)*)Select the Pool.*:');
print $wait_for_input;
if ($rv == 0) {
	&job_error($text{'label_eexists'});
	}
elsif ($rv == 2) {
	# Need to choose a pool
	if ($matches[1] =~ /(\d+):\s+\Q$in{'pool'}\E/) {
		&sysprint($h->{'infh'}, "$1\n");
		}
	else {
		&job_error($text{'label_epool'});
		}
	}

$rv = &wait_for($h->{'outfh'}, 'success.*\\n', 'failed.*\\n');
print $wait_for_input;
if ($rv == 1) {
	&job_error($text{'label_efailed'});
	}

print "</pre>";
print "<b>$text{'label_done'}</b><p>\n";

&close_console($h);
&webmin_log("label", $in{'storage'});

&ui_print_footer("label_form.cgi", $text{'label_return'});

sub job_error
{
&close_console($h);
print "</pre>\n";
print "<b>",@_,"</b><p>\n";
&ui_print_footer("label_form.cgi", $text{'label_return'});
exit;
}

