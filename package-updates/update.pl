#!/usr/local/bin/perl
# Check for and install updates

$no_acl_check++;
require './package-updates-lib.pl';

# See what needs doing
@current = &list_current(1);
@avail = &list_available(1);
foreach $c (sort { $a->{'name'} cmp $b->{'name'} } @current) {
	($a) = grep { $_->{'name'} eq $c->{'name'} &&
		      $_->{'system'} eq $c->{'system'} } @avail;
	if ($a->{'version'} && &compare_versions($a, $c) > 0) {
		# An update is available
		push(@todo, { 'name' => $c->{'name'},
			      'update' => $a->{'update'},
			      'version' => $a->{'version'},
			      'desc' => "New version released",
			      'level' => $a->{'security'} ? 1 : 2 });
		}
	}

# Install packages that are needed
$tellcount = 0;
foreach $t (@todo) {
	if ($t->{'level'} <= $config{'sched_action'}) {
		# Can install
		$body .= "An update to $t->{'name'} $t->{'version'} is needed : $t->{'desc'}\n";
		($out, $done) = &capture_function_output(
				  \&package_install, $t->{'update'});
		if (@$done) {
			$body .= "This update has been successfully installed.\n\n";
			}
		else {
			$body .= "However, this update could not be installed! Try the update manually\nusing the Security Updates module.\n\n";
			}
		}
	else {
		# Just tell the user about it
		$body .= "An update to $t->{'name'} $t->{'version'} is available : $t->{'desc'}\n\n";
		$tellcount++;
		}
	}

if ($tellcount) {
	# Add link to Webmin
	&get_miniserv_config(\%miniserv);
	$proto = $miniserv{'ssl'} ? 'https' : 'http';
	$port = $miniserv{'port'};
	$url = $proto."://".&get_system_hostname().":".$port."/$module_name/";
	$body .= "Updates can be installed at $url\n\n";
	}

# Email the admin
if ($config{'sched_email'} && $body) {
	&foreign_require("mailboxes", "mailboxes-lib.pl");
	local $from = &mailboxes::get_from_address();
	local $mail = { 'headers' =>
			[ [ 'From', $from ],
			  [ 'To', $config{'sched_email'} ],
			  [ 'Subject', "Security updates" ] ],
			'attach' =>
			[ { 'headers' => [ [ 'Content-type', 'text/plain' ] ],
			    'data' => $body } ] };
	&mailboxes::send_mail($mail, undef, 1, 0);
	}

