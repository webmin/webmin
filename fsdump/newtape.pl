#!/usr/local/bin/perl
# newtape.pl
# Called when a new tape is needed for some backup, to update its status
# file. Only exits when the user has actually clicked the 'new tape' button

$no_acl_check++;
delete($ENV{'SCRIPT_NAME'});	# force use of $0 to determine module
delete($ENV{'FOREIGN_MODULE_NAME'});
require './fsdump-lib.pl';
$dump = &get_dump($ARGV[0]);
$dump->{'id'} || die "Dump $ARGV[0] does not exist!";

# Find the status file
opendir(DIR, $module_config_directory);
foreach $f (readdir(DIR)) {
	if ($f =~ /^(\d+)\.(\d+)\.status$/ && $1 eq $dump->{'id'}) {
		# Got it!
		$sfile = "$module_config_directory/$f";
		}
	}
closedir(DIR);
$sfile || die "Failed to find status file for dump $ARGV[0]";

# Update it to indicate that a new tape is needed
&read_file($sfile, \%status);
$status{'status'} = 'tape';
$status{'tapepid'} = $$;
$status{'tapecount'}++;
&write_file($sfile, \%status);

# Email the backup address
if ($dump->{'email'} && &foreign_check("mailboxes")) {
	&foreign_require("mailboxes", "mailboxes-lib.pl");
	$host = &get_system_hostname();
	$c = $status{'tapecount'};
	@dirs = &dump_directories($dump);
	$dirs = join(", ", @dirs);
	$subject = &text('newtape_subject', $c, $dirs, $host);
	$data = &text('newtape_body', $c, $dirs, $host)."\n";
	&mailboxes::send_text_mail(&mailboxes::get_from_address(),
				   $dump->{'email'},
				   undef,
				   $subject,
				   $data,
				   $config{'smtp_server'});
	}

# Wait until signalled with a HUP
$SIG{'HUP'} = \&got_hup;
while(1) {
	sleep(1000000);
	}
exit(2);

sub got_hup
{
$status{'status'} = 'running';
&write_file($sfile, \%status);
exit(0);
}

