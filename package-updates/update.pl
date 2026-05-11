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
			}
		foreach $p (@$done) {
			$already{$p}++;
			}
		}
	elsif ($config{'sched_action'} == 1 ||
	       $config{'sched_action'} == 0 ||
	       $config{'sched_action'} == -1 && $t->{'security'}) {
		# Just tell the user about it
		$body .= "$upfx $umsg to $t->{'name'} from $t->{'oldversion'} ".
			 "to $t->{'version'} is available.\n\n";
		$tellcount++;
		}
	}
&end_update_progress();

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
