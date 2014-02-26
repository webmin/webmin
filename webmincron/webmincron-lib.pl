=head1 webmincron-lib.pl

Functions for creating and listing Webmin scheduled functions.

=cut

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

$webmin_crons_directory = "$module_config_directory/crons";
@special_modes = ( 'hourly', 'daily', 'weekly', 'monthly', 'yearly' );

=head2 list_webmin_crons

Returns a list of all scheduled Webmin functions. Each of which is a hash ref
with keys :

=item id - A unique ID number

=item module - The module in which the function is defined

=item file - File in which the function is declared

=item func - Name of the function to call

=item args - Array ref of strings to pass to the function as parameters

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
		my @args;
		for(my $i=0; defined($cron{'arg'.$i}); $i++) {
			push(@args, $cron{'arg'.$i});
			delete($cron{'arg'.$i});
			}
		if (@args) {
			$cron{'args'} = \@args;
			}
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
my %wcron = %$cron;
if ($wcron{'args'}) {
	for(my $i=0; $i<@{$wcron{'args'}}; $i++) {
		$wcron{'arg'.$i} = $wcron{'args'}->[$i];
		}
	delete($wcron{'args'});
	}
&lock_file($file);
&write_file($file, \%wcron);
&unlock_file($file);
&reload_miniserv(1);
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
&reload_miniserv(1);
}

=head2 find_webmin_cron(module, function, [&args])

Returns a Webmin cron hash ref matching the given module and function

=cut
sub find_webmin_cron
{
my ($module, $func, $args) = @_;
my @crons = &list_webmin_crons();
foreach my $oc (@crons) {
	next if ($oc->{'module'} ne $module);
	next if ($oc->{'func'} ne $func);
	if ($args) {
		my $sameargs = 1;
		for(my $i=0; $i < scalar(@{$oc->{'args'}}) ||
			     $i < scalar(@$args); $i++) {
			$sameargs = 0 if ($oc->{'args'}->[$i] ne $args->[$i]);
			}
		next if (!$sameargs);
		}
	return $oc;
	}
return undef;
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
my $already = &find_webmin_cron($cron->{'module'}, $cron->{'func'},
				$cron->{'args'});
if ($already) {
	# Update existing, possibly with new interval
	$cron->{'id'} = $already->{'id'};
	}
&save_webmin_cron($cron);

# Find and delete any Unix cron job that this is replacing
if ($old_cmd && &foreign_installed("cron")) {
	&foreign_require("cron");
	my @jobs = &cron::list_cron_jobs();
	@jobs = grep {
	     $_->{'user'} eq 'root' &&
	     $_->{'command'} =~ /(^|[ \|\&;\/])\Q$old_cmd\E($|[ \|\&><;])/
	     } @jobs;
	foreach my $job (reverse(@jobs)) {
		&lock_file(&cron::cron_file($job));
		&cron::delete_cron_job($job);
		&unlock_file(&cron::cron_file($job));
		}
	}
}

=head2 delete_webmin_module_crons(module)

Remove all Webmin cron jobs for some module

=cut
sub delete_webmin_module_crons
{
my ($mod) = @_;
foreach my $cron (&list_webmin_crons()) {
	if ($cron->{'module'} eq $mod) {
		&delete_webmin_cron($cron);
		}
	}
}

=head2 show_times_input(&job, [special])

Returns HTML for inputs for selecting the schedule for a cron job, defined
by the first parameter which must be a hash ref returned by list_cron_jobs.

=item job - Hash ref for a webmincron object

=item special - 0=don't allow special times (like @hourly), 1=allow

=cut
sub show_times_input
{
my ($job, $special) = @_;
$special = 0 if (!defined($special));
my $rv = "<table width=100%>\n";
if ($special || $job->{'special'}) {
	# Allow selection of special @ times
	$rv .= "<tr $cb> <td colspan=6>\n";
	$rv .= &ui_radio("special_def", $job->{'special'} ? 1 : 0,
		[ [ 1, $text{'edit_special1'}." ".
		       &ui_select("special", $job->{'special'},
				  [ map { [ $_, $text{'edit_special_'.$_} ] }
					@special_modes ]) ],
		  [ 0, $text{'edit_special0'} ] ]);
	$rv .= "</td></tr>\n";
	}

# Javascript to disable and enable fields
$rv .= <<EOF;
<script>
function enable_cron_fields(name, form, ena)
{
var els = form.elements[name];
els.disabled = !ena;
for(i=0; i<els.length; i++) {
  els[i].disabled = !ena;
  }
}
</script>
EOF

$rv .= "<tr $tb>\n";
$rv .= "<td><b>$text{'edit_mins'}</b></td> ".
       "<td><b>$text{'edit_hours'}</b></td> ".
       "<td><b>$text{'edit_days'}</b></td> ".
       "<td><b>$text{'edit_months'}</b></td> ".
       "<td><b>$text{'edit_weekdays'}</b></td>";
$rv .= "</tr> <tr $cb>\n";

my @mins = (0..59);
my @hours = (0..23);
my @days = (1..31);
my @months = map { $text{"month_$_"}."=".$_ } (1 .. 12);
my @weekdays = map { $text{"day_$_"}."=".$_ } (0 .. 6);
my $arrmap = { 'mins' => \@mins,
	       'hours' => \@hours,
	       'days' => \@days,
	       'months' => \@months,
	       'weekdays' => \@weekdays };

foreach my $arr ("mins", "hours", "days", "months", "weekdays") {
	# Find out which ones are being used
	my %inuse;
	my $min = ($arr =~ /days|months/ ? 1 : 0);
	my $max = $min+scalar(@{$arrmap->{$arr}})-1;
	foreach my $w (split(/,/ , $job->{$arr})) {
		if ($w eq "*") {
			# all values
			for(my $j=$min; $j<=$max; $j++) { $inuse{$j}++; }
			}
		elsif ($w =~ /^\*\/(\d+)$/) {
			# only every Nth
			for(my $j=$min; $j<=$max; $j+=$1) { $inuse{$j}++; }
			}
		elsif ($w =~ /^(\d+)-(\d+)\/(\d+)$/) {
			# only every Nth of some range
			for(my $j=$1; $j<=$2; $j+=$3) { $inuse{int($j)}++; }
			}
		elsif ($w =~ /^(\d+)-(\d+)$/) {
			# all of some range
			for(my $j=$1; $j<=$2; $j++) { $inuse{int($j)}++; }
			}
		else {
			# One value
			$inuse{int($w)}++;
			}
		}
	if ($job->{$arr} eq "*") { undef(%inuse); }

	# Output selection list
	$rv .= "<td valign=top>\n";
        $rv .= sprintf
		"<input type=radio name=all_$arr value=1 %s %s %s> %s<br>\n",
                $arr eq "mins" && $hourly_only ? "disabled" : "",
		$job->{$arr} eq "*" ||  $job->{$arr} eq "" ? "checked" : "",
		"onClick='enable_cron_fields(\"$arr\", form, 0)'",
		$text{'edit_all'};
	$rv .= sprintf
		"<input type=radio name=all_$arr value=0 %s %s> %s<br>\n",
		$job->{$arr} eq "*" || $job->{$arr} eq "" ? "" : "checked",
		"onClick='enable_cron_fields(\"$arr\", form, 1)'",
		$text{'edit_selected'};
	$rv .= "<table> <tr>\n";
	my @arrlist = @{$arrmap->{$arr}};
        for(my $j=0; $j<@arrlist; $j+=12) {
                my $jj = $j + 11;
		if ($jj >= @arrlist) { $jj = @arrlist - 1; }
		my @sec = @arrlist[$j .. $jj];
                $rv .= sprintf
			"<td valign=top><select %s size=%d name=$arr %s>\n",
                        $arr eq "mins" && $hourly_only ? "" : "multiple",
                        @sec > 12 ? 12 : scalar(@sec),
			$job->{$arr} eq "*" ||  $job->{$arr} eq "" ?
				"disabled" : "";
		foreach my $v (@sec) {
			if ($v =~ /^(.*)=(.*)$/) { $disp = $1; $code = $2; }
			else { $disp = $code = $v; }
			$rv .= sprintf "<option value=\"$code\" %s>$disp</option>\n",
				$inuse{$code} ? "selected" : "";
			}
		$rv .= "</select></td>\n";
		}
	$rv .= "</tr></table></td>\n";
	}
$rv .= "</tr></table>\n";
return $rv;
}

=head2 parse_times_input(&job, &in)

Parses inputs from the form generated by show_times_input, and updates a cron
job hash ref. The in parameter must be a hash ref as generated by the 
ReadParse function.

=cut
sub parse_times_input
{
my $job = $_[0];
my %in = %{$_[1]};
my @pers = ("mins", "hours", "days", "months", "weekdays");
if ($in{'special_def'}) {
	# Job time is a special period
	foreach my $arr (@pers) {
		delete($job->{$arr});
		}
	$job->{'special'} = $in{'special'};
	}
else {
	# User selection of times
	foreach my $arr (@pers) {
		if ($in{"all_$arr"}) {
			# All mins/hrs/etc.. chosen
			$job->{$arr} = "*";
			}
		elsif (defined($in{$arr})) {
			# Need to work out and simplify ranges selected
			my @range = split(/\0/, $in{$arr});
			my @range = sort { $a <=> $b } @range;
			my @newrange;
			my $start = -1;
			for(my $i=0; $i<@range; $i++) {
				if ($i && $range[$i]-1 == $range[$i-1]) {
					# ok.. looks like a range
					if ($start < 0) { $start = $i-1; }
					}
				elsif ($start < 0) {
					# Not in a range at all
					push(@newrange, $range[$i]);
					}
				else {
					# End of the range.. add it
					$newrange[@newrange - 1] =
						"$range[$start]-".$range[$i-1];
					push(@newrange, $range[$i]);
					$start = -1;
					}
				}
			if ($start >= 0) {
				# Reached the end while in a range
				$newrange[@newrange - 1] =
					"$range[$start]-".$range[$i-1];
				}
			$job->{$arr} = join(',' , @newrange);
			}
		else {
			&error(&text('save_enone', $text{"edit_$arr"}));
			}
		}
	delete($job->{'special'});
	}
}



1;

