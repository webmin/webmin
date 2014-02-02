#!/usr/local/bin/perl
# edit_cron.cgi
# Show fetchmail cron configuration

require './fetchmail-lib.pl';
&foreign_require("cron", "cron-lib.pl");
$can_cron || &error($text{'cron_ecannot2'});
&ui_print_header(undef, $text{'cron_title'}, "");

print "$text{'cron_desc'}<p>\n";

# Get the cron job
@jobs = &cron::list_cron_jobs();
($job) = grep { $_->{'user'} eq $cron_user &&
		$_->{'command'} =~ /^$cron_cmd/ } @jobs;

print &ui_form_start("save_cron.cgi");
print &ui_table_start($text{'cron_header'}, "width=100%", 2);

if ($job) {
	if ($job->{'command'} =~ /--mail\s+(\S+)/) {
		$mail = `echo $1`;
		}
	elsif ($job->{'command'} =~ /--file\s+(\S+)/) {
		$file = `echo $1`;
		}
	elsif ($job->{'command'} =~ /--output/) {
		$output = 1;
		}
	elsif ($job->{'command'} =~ /--owner/) {
		$owner = 1;
		}
	if ($job->{'command'} =~ /--user\s+(\S+)/) {
		$user = $1;
		}
	if ($job->{'command'} =~ /--errors/) {
		$errors = 1;
		}
	}

print &ui_table_row($text{'cron_output'},
		   &ui_radio("output", $owner ? 4 : $output ? 3 : $mail ? 2 : $file ? 1 : 0,
			     [ [ 0, $text{'cron_throw'}."<br>" ],
			       [ 3, $text{'cron_cron'}."<br>" ],
			       [ 1, &text('cron_file',
				&ui_textbox("file", $file, 30))."<br>" ],
			       [ 2, &text('cron_mail',
				&ui_textbox("mail", $mail, 30))."<br>" ],
			       $fetchmail_config ? ( ) :
				 ( [ 4, $text{'cron_owner'}."<br>" ] ) ]));

print &ui_table_row($text{'cron_errors'},
		    &ui_radio("errors", $errors ? 1 : 0,
			      [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

if ($cron_user eq "root" && $fetchmail_config) {
	print &ui_table_row($text{'cron_user'},
			    &ui_user_textbox("user", $user || "root"));
	}

print &ui_table_row($text{'cron_enabled'},
		    &ui_radio("enabled", $job ? 1 : 0,
			      [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

$job ||= { 'special' => 'hourly' };
print &cron::get_times_input($job);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});


