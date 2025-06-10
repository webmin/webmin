#!/usr/local/bin/perl
# Send email to users approaching their quotas

$no_acl_check++;
require './quota-lib.pl';
&foreign_require("mailboxes", "mailboxes-lib.pl");

# Find filesystems with quotas
foreach $fs (&list_filesystems()) {
	if ($fs->[4] && $fs->[5]) {
		$fslist{$fs->[0]}++;
		}
	}

# Look for filesystems with warning enabled
$now = time();
foreach $k (keys %config) {
	if ($k =~ /^email_(\S+)$/ && $fslist{$1}) {
		# Found a filesystem to check users on
		$f = $1;
		%user = ( );
		$n = &filesystem_users($f);
		local %emailtimes;
		local $qf = $f;
		$qf =~ s/\//_/g;
		&read_file("$module_config_directory/emailtimes.$qf",
			   \%emailtimes);
		$interval = $config{'email_interval_'.$f}*60*60;

		for($i=0; $i<$n; $i++) {
			if ($config{'email_type_'.$f}) {
				$limit = $user{$i,'hblocks'};
				}
			else {
				$limit = $user{$i,'sblocks'};
				}
			next if (!$limit);

			# Check if over threshold
			$upercent = 100.0*$user{$i,'ublocks'}/$limit;
			next if ($upercent < $config{'email_percent_'.$f});

			# Check if time to email
			next if ($emailtimes{$user{$i,'user'}} >=
				 $now - $interval);

			# Work out the domain, perhaps from Virtualmin
			$email = $user{$i,'user'}."\@".
				 $config{'email_domain_'.$f};
			if ($config{'email_virtualmin_'.$f} &&
			    &foreign_check("virtual-server")) {
				&foreign_require("virtual-server",
						 "virtual-server-lib.pl");
				local $d = &virtual_server::get_user_domain(
						$user{$i,'user'});
				if ($d) {
					local @users = &virtual_server::list_domain_users($d, 0, 0, 1, 1);
					local ($uinfo) = grep { $_->{'user'} eq $user{$i,'user'} } @users;
					if ($uinfo && $uinfo->{'domainowner'}) {
						# Domain owner, with own email
						$email = $d->{'emailto'};
						}
					elsif ($uinfo && $uinfo->{'email'}) {
						# Regular user with email
						$email = $uinfo->{'email'};
						}
					}
				}

			# Email the user
			&send_quota_mail(
				$user{$i,'user'},
				$email,
				$limit,
				$user{$i,'ublocks'},
				$f,
				$upercent,
				$config{'email_from_'.$f},
				$user{$i,'gblocks'},
				'email',
				$config{'email_cc_'.$f},
				);

			# Save last email time
			$emailtimes{$user{$i,'user'}} = $now;
			}

		&write_file("$module_config_directory/emailtimes.$qf",
			    \%emailtimes);
		}

	if ($k =~ /^gemail_(\S+)$/ && $fslist{$1}) {
		# Found a filesystem to check groups on
		$f = $1;
		$n = &filesystem_groups($f);
		local %emailtimes;
		local $qf = $f;
		$qf =~ s/\//_/g;
		&read_file("$module_config_directory/gemailtimes.$qf",
			   \%emailtimes);
		$interval = $config{'gemail_interval_'.$f}*60*60;

		for($i=0; $i<$n; $i++) {
			if ($config{'gemail_type_'.$f}) {
				$limit = $group{$i,'hblocks'};
				}
			else {
				$limit = $group{$i,'sblocks'};
				}
			next if (!$limit);

			# Check if over threshold
			$upercent = 100.0*$group{$i,'ublocks'}/$limit;
			next if ($upercent < $config{'gemail_percent_'.$f});

			# Check if time to email
			next if ($emailtimes{$group{$i,'group'}} >=
				 $now - $interval);

			# Work out the destination
			local $to;
			if ($config{'gemail_tomode_'.$f} == 0) {
				# Same name as group
				$to = $group{$i,'group'};
				}
			elsif ($config{'gemail_tomode_'.$f} == 1) {
				# Fixed address
				$to = $config{'gemail_to_'.$f};
				}
			else {
				# From Virtualmin
				&foreign_require("virtual-server",
						 "virtual-server-lib.pl");
				local $d = &virtual_server::get_domain_by(
					"group", $group{$i,'group'},
					"parent", undef);
				if ($d) {
					$to = $d->{'emailto'} || $d->{'email'};
					}
				}

			local $cc = $config{'gemail_cc_'.$f};
			if (!$to && $cc) {
				# No to address, such as when a virtualmin
				# domain was not found. So still send to the 
				# CC address
				$to = $cc;
				$cc = undef;
				}
			if ($to) {
				# Email the responsible person
				if ($to !~ /\@/) {
					local $dom =
					    $config{'email_domain_'.$f} ||
					    &get_system_hostname();
					$to .= "\@$dom";
					}
				&send_quota_mail(
					$group{$i,'group'},
					$to,
					$limit,
					$group{$i,'ublocks'},
					$f,
					$upercent,
					$config{'gemail_from_'.$f},
					$group{$i,'gblocks'},
					'gemail',
					$cc,
					);
				}

			# Save last email time
			$emailtimes{$group{$i,'group'}} = $now;
			}

		&write_file("$module_config_directory/gemailtimes.$qf",
			    \%emailtimes);
		}
	}

sub send_quota_mail
{
local ($user, $addr, $limit, $used, $fs, $percent, $from, $grace, $suffix,
       $ccaddr) = @_;
local $bsize = &block_size($fs);
if ($bsize) {
	$used = &nice_size($used*$bsize);
	$limit = &nice_size($limit*$bsize);
	}
else {
	$used = "$used blocks";
	$limit = "$limit blocks";
	}
local $body;
local %hash = ( 'USER' => $user,
		'FS' => $fs,
		'PERCENT' => int($percent),
		'USED' => $used,
		'QUOTA' => $limit,
		'GRACE' => $grace, );
if ($config{$suffix.'_msg'}) {
	# Use configured template
	$body = &substitute_template($config{$suffix.'_msg'}, \%hash);
	$body =~ s/\t/\n/g;
	}
else {
	# Fall back to default
	$body = &text($suffix.'_msg', $user, $fs, int($percent), $used,$limit);
	$body =~ s/\\n/\n/g;
	}
local $subject;
if ($config{$suffix.'_subject'}) {
	# Use configured subject
	$subject = &substitute_template($config{$suffix.'_subject'}, \%hash);
	}
else {
	# Fall back to default
	$subject = $text{$suffix.'_subject'};
	}
&mailboxes::send_text_mail($from || &mailboxes::get_from_address(),
			   $addr,
			   undef,
			   $subject,
			   $body);
if ($ccaddr) {
	# Also send to other address (like the domain owner)
	&mailboxes::send_text_mail($from || &mailboxes::get_from_address(),
				   $ccaddr,
				   undef,
				   $subject,
				   $body);
	}
}

