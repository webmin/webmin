#!/usr/local/bin/perl
# Check for and install updates

$no_acl_check++;
require './package-updates-lib.pl';

if ($ARGV[0] eq "--debug" || $ARGV[0] eq "-debug") {
	$debug = 1;
	}

# See what needs doing
&flush_package_caches();
&clear_repository_cache();
@todo = &list_possible_updates();

# Install packages that are needed
$tellcount = 0;
%already = ( );
&start_update_progress([ map { $_->{'name'} } @todo ]);
$icount = 0;
foreach $t (@todo) {
	next if ($already{$t->{'update'}});
	my $umsg = $t->{'security'} ? "security update" : "update";
	my $upfx = $t->{'security'} ? "A" : "An";
	if ($config{'sched_action'} == 2 ||
	    $config{'sched_action'} == 1 && $t->{'security'}) {
		# Can install
		$body .= "$upfx $umsg to $t->{'name'} from $t->{'oldversion'} to $t->{'version'} is needed.\n";
		$icount++;
		($out, $done) = &capture_function_output(
				  \&package_install, $t->{'update'});
		if (@$done) {
			$body .= "This $umsg has been successfully installed.\n\n";
			}
		else {
			$body .= "However, this $usmg could not be installed! Try the update manually\nusing the Package Updates module.\n\n";
			}
		foreach $p (@$done) {
			$already{$p}++;
			}
		}
	elsif ($config{'sched_action'} == 1 ||
	       $config{'sched_action'} == 0 ||
	       $config{'sched_action'} == -1 && $t->{'security'}) {
		# Just tell the user about it
		$body .= "$upfx $umsg to $t->{'name'} from $t->{'oldversion'} to $t->{'version'} is available.\n\n";
		$tellcount++;
		}
	}
&end_update_progress();

if ($tellcount) {
	# Add link to Webmin
	$url = &get_webmin_email_url($module_name);
	$body .= "Updates can be installed at $url\n\n";
	}

# Email the admin
$emailto = $config{'sched_email'} eq '*' ? $gconfig{'webmin_email_to'}
					 : $config{'sched_email'};
if ($emailto && $body) {
	&foreign_require("mailboxes", "mailboxes-lib.pl");
	my $from = &mailboxes::get_from_address();
	my $mail = { 'headers' =>
			[ [ 'From', $from ],
			  [ 'To', $emailto ],
			  [ 'Subject', "Package updates on ".
				       &get_system_hostname() ] ],
			'attach' =>
			[ { 'headers' => [ [ 'Content-type', 'text/plain' ] ],
			    'data' => $body } ] };
	&mailboxes::send_mail($mail, undef, 1, 0);
	if ($debug) {
		print STDERR $body;
		}
	}

# Log the update, if anything was installed
if ($icount) {
	&webmin_log("schedup", "packages", $icount);
	}
