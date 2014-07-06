#!/usr/local/bin/perl
# Send email when a system is down

$no_acl_check++;
require './cluster-shutdown-lib.pl';
&foreign_require("mailboxes", "mailboxes-lib.pl");

@servers = grep { $_->{'user'} } &servers::list_servers();
%up = &get_all_statuses(\@servers);
$last_status_file = "$module_config_directory/last";

&read_file($last_status_file, \%oldstatus);

foreach $s (@servers) {
	if (!$up{$s} && $oldstatus{$s->{'id'}}) {
		# Just went down .. send email
		local $mail =
			{ 'headers' => [ [ 'From', 'webmin@'.&get_system_hostname() ],
				       [ 'To', $config{'email'} ],
				       [ 'Subject', "System $s->{'host'} is down" ],
					     ],
			'attach' =>
				[ { 'headers' => [ [ 'Content-type', 'text/plain' ] ],
				    'data' => "The system $s->{'host'} has gone down!" } ]
		      };
		&mailboxes::send_mail($mail, undef, undef, 0, $config{'smtp'});
		}
	$oldstatus{$s->{'id'}} = $up{$s};
	}

&write_file($last_status_file, \%oldstatus);

