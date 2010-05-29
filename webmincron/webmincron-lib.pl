=head1 webmincron-lib.pl

Functions for creating and listing Webmin scheduled functions.

=cut

# XXX UI
# XXX support cron-style time specs
# XXX make sure temp files are cleaned up
# XXX switch all cron jobs at install time
# XXX delete jobs when un-installing modules

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
$webmin_crons_directory = "$module_config_directory/crons";

=head2 list_webmin_crons

Returns a list of all scheduled Webmin functions. Each of which is a hash ref
with keys :

=item id - A unique ID number

=item module - The module in which the function is defined

=item file - File in which the function is declared

=item func - Name of the function to call

=item arg0,arg1,etc.. - Strings to pass to the function as parameters

=item interval - Number of seconds between runs (optional)

=item mins - Minutes on which to run. Can be * or a comma-separated list

=item hours - Hours on which to run

=item days - Days of the month on which to run

=item months - Months of the year on which to run

=item weekdays - Days of week on which to run

=item special - Can be 'hourly', 'daily', 'weekly' or 'monthly'

=cut
sub list_webmin_crons
{
my @rv;
opendir(CRONS, $webmin_crons_directory) || return ( );
foreach my $f (readdir(CRONS)) {
	if ($f =~ /^(\d+)\.cron$/) {
		my %cron;
		&read_file_cached("$webmin_crons_directory/$f", \%cron);
		$cron{'id'} = $1;
		push(@rv, \%cron);
		}
	}
return @rv;
}

=head2 save_webmin_crons(&cron)

Create or update a webmin cron function. Also locks the file being written to.

=cut
sub save_webmin_cron
{
my ($cron) = @_;
if (!-d $webmin_crons_directory) {
	&make_dir($webmin_crons_directory, 0700);
	}
if (!$cron->{'id'}) {
	$cron->{'id'} = time().$$;
	}
my $file = "$webmin_crons_directory/$cron->{'id'}.cron";
&lock_file($file);
&write_file($file, $cron);
&unlock_file($file);
&reload_miniserv();
}

=head2 delete_webmin_cron(&cron)

Deletes the file for a webmin cron function. Also does locking.

=cut
sub delete_webmin_cron
{
my ($cron) = @_;
my $file = "$webmin_crons_directory/$cron->{'id'}.cron";
&lock_file($file);
&unlink_file($file);
&unlock_file($file);
&reload_miniserv();
}

=head2 create_webmin_cron(&cron, [old-cron-command])

Create or update a webmin cron job that calls some function.
If the old-cron parameter is given, find and replace the regular cron job
of that name.

=cut
sub create_webmin_cron
{
my ($cron, $old_cmd) = @_;

# Find and replace existing cron with same module, function and args
my @crons = &list_webmin_crons();
my $already;
foreach my $oc (@crons) {
	next if ($oc->{'module'} ne $cron->{'module'});
	next if ($oc->{'func'} ne $cron->{'func'});
	my $sameargs = 1;
	for(my $i=0; defined($oc->{'arg'.$i}) ||
		     defined($cron->{'arg'.$i}); $i++) {
		$sameargs = 0 if ($oc->{'arg'.$i} ne $cron->{'arg'.$i});
		}
	next if (!$sameargs);
	$already = $oc;
	last;
	}
if ($already) {
	# Update existing, possibly with new interval
	$cron->{'id'} = $already->{'id'};
	}
&save_webmin_cron($cron);

# Find and delete any Unix cron job that this is replacing
if ($old_cmd && &foreign_installed("cron")) {
	&foreign_require("cron");
	my @jobs = &cron::list_cron_jobs();
	my ($job) = grep {
	     $_->{'user'} eq 'root' &&
	     $_->{'command'} =~ /(^|[ \|\&;\/])\Q$old_cmd\E($|[ \|\&><;])/
	     } @jobs;
	if ($job) {
		&lock_file(&cron::cron_file($job));
		&cron::delete_cron_job($job);
		&unlock_file(&cron::cron_file($job));
		}
	}
}

1;

