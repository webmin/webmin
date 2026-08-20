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
@updated = ( );
@toinstall = grep { &scheduled_update_should_install($_) } @todo;
if (@toinstall && $config{'sched_pre_script'}) {
	my @pending = &unique(map { $_->{'update'} } @toinstall);
	($pre_ok, $pre_body) = &run_update_script(
		$config{'sched_pre_script'}, "pre", @pending);
	$body .= $pre_body;
	if (!$pre_ok) {
		$body .= "Scheduled package updates were skipped because the ".
			 "pre-update script failed or could not be run.\n\n";
		}
	}
else {
	$pre_ok = 1;
	}
&start_update_progress([ map { $_->{'name'} } @todo ]);
$icount = 0;
$fcount = 0;

# Track the updates that may need to be reported
$newonly = $config{'sched_when'} == 3;
$newcount = 0;
$tellbody = "";
%notified = ( );
%pending = ( );
foreach $t (@todo) {
	next if ($already{$t->{'update'}});
	my $umsg = $t->{'security'} ? "security update" : "update";
	my $upfx = $t->{'security'} ? "A" : "An";
	if (&scheduled_update_should_install($t)) {
		# Can install
		$body .= "$upfx $umsg to $t->{'name'} from $t->{'oldversion'} ".
			 "to $t->{'version'} is needed.\n";
		if (!$pre_ok) {
			$body .= "This $umsg was skipped because the pre-".
				 "update script failed or could not be run.\n\n";
			next;
			}
		($out, $done) = &capture_function_output(
				  \&package_install, $t->{'update'});
		if (@$done) {
			$body .= "This $umsg has been successfully installed.\n\n";
			$icount++;
			push(@updated, @$done);
			}
		else {
			$body .= "However, this $umsg could not be installed! ".
				 "Try the update manually\nusing the Package ".
				 "Updates module.\n\n";
			$fcount++;
			}
		foreach $p (@$done) {
			$already{$p}++;
			}
		}
	elsif ($config{'sched_action'} == 1 ||
	       $config{'sched_action'} == 0 ||
	       $config{'sched_action'} == -1 && $t->{'security'}) {
		# Add this update to the complete pending report
		my $key = $t->{'system'}."/".$t->{'name'};
		$pending{$key} = $t->{'version'};
		$tellbody .= "$upfx $umsg to $t->{'name'} from ".
			     "$t->{'oldversion'} to $t->{'version'} is ".
			     "available.\n\n";
		$tellcount++;
		}
	}
&end_update_progress();

# Serialize the notification decision with the state update, so overlapping
# runs cannot both report the same new updates
if ($newonly) {
	&lock_file($notified_file);
	&read_file($notified_file, \%notified);
	foreach my $key (keys %pending) {
		$newcount++ if ($notified{$key} ne $pending{$key});
		}
	}

# In new-only mode, skip the list entirely if nothing changed. If something is
# new, still include everything pending so the email is complete
if ($newonly && !$newcount) {
	$tellcount = 0;
	}
else {
	$body .= $tellbody;
	}

if (@updated && $config{'sched_post_script'}) {
	my @unique_updated = &unique(@updated);
	my ($post_ok, $post_body) = &run_update_script(
		$config{'sched_post_script'}, "post", @unique_updated);
	$body .= $post_body;
	}

if ($tellcount) {
	# Add link to Webmin
	$url = &get_webmin_email_url($module_name);
	$body .= "Updates can be installed at $url\n\n";
	}

# Email the admin
$emailto = $config{'sched_email'};
if ($emailto eq '*') {
	$emailto = $gconfig{'webmin_email_to'};
	if ($emailto && $gconfig{'webmin_email_to_name'}) {
		$emailto = "$gconfig{'webmin_email_to_name'} <$emailto>";
		}
	}
if ($emailto && $body &&
    ($config{'sched_when'} == 0 || $newonly ||
     $config{'sched_when'} == 1 && $fcount)) {
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
	$sent = 1;
	if ($debug) {
		print STDERR $body;
		}
	}

# Remember what was reported, but only if the email was actually sent
if ($newonly && ($sent || !%pending)) {
	&write_file($notified_file, \%pending);
	}
if ($newonly) {
	&unlock_file($notified_file);
	}

# Log the update, if anything was installed
if ($icount) {
	&webmin_log("schedup", "packages", $icount);
	}

# scheduled_update_should_install(&update)
# Returns 1 if the scheduled update action allows this package to be installed.
sub scheduled_update_should_install
{
my ($update) = @_;
return $config{'sched_action'} == 2 ||
       $config{'sched_action'} == 1 && $update->{'security'};
}

# run_update_script(script, phase, packages...)
# Runs a pre or post-update hook script and returns a status flag and message.
sub run_update_script
{
my ($script, $phase, @packages) = @_;
my $label = $phase eq "pre" ? "Pre-update" : "Post-update";
if (!-f $script || !-x $script) {
	return (0, "$label script $script was not run because it is not ".
		   "executable.\n\n");
	}

local $ENV{'WEBMIN_PACKAGE_UPDATES'} = join(" ", @packages);
local $ENV{'WEBMIN_PACKAGE_UPDATE_COUNT'} = scalar(@packages);
local $ENV{'WEBMIN_PACKAGE_UPDATE_PHASE'} = $phase;
my $out = &backquote_logged(&quote_path($script)." 2>&1 </dev/null");
if ($?) {
	my $status = ($? & 127) ? "signal ".($? & 127)
				: "exit status ".($? >> 8);
	return (0, "$label script $script failed with $status.\n".
		   ($out ? $out."\n" : "")."\n");
	}
return (1, "$label script $script was run successfully.\n".
	   ($out ? $out."\n" : "")."\n");
}
