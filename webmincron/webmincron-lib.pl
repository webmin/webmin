=head1 webmincron-lib.pl

Functions for creating and listing Webmin scheduled functions.

=cut

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

=item interval - Number of seconds between runs

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
}

=head2 create_webmin_cron(module, function, interval, &args)

=cut
sub create_webmin_cron
{
}

1;

