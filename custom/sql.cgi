#!/usr/local/bin/perl
# Execute some SQL and display the result

require './custom-lib.pl';
if ($ENV{'CONTENT_TYPE'} =~ /multipart\/form-data/i) {
	&ReadParseMime();
	}
else {
	&ReadParse();
	}
&error_setup($text{'srun_err'});
$cmd = &get_command($in{'id'}, $in{'idx'});
&can_run_command($cmd) || &error($text{'run_ecannot'});

# Connect to the DB
use DBI;
$drh = DBI->install_driver($cmd->{'type'});
$drh || &error($text{'srun_edriver'});
($driver) = grep { $_->{'driver'} eq $cmd->{'type'} } &list_dbi_drivers();
$dbh = $drh->connect($driver->{'dbparam'}."=".$cmd->{'db'}.
		     ($cmd->{'host'} ? ";host=$cmd->{'host'}" : ""),
		     $cmd->{'user'}, $cmd->{'pass'}, { });
$dbh || &error(&text('srun_econnect', $drh->errstr));

# Show header
&ui_print_unbuffered_header(undef, $text{'srun_title'}, "");
print &text('srun_cmd', "<tt>$cmd->{'sql'}</tt>"),"<p>\n";

# Work out params
($env, $export, $str, $displaystr, $args) = &set_parameter_envs($cmd, $cmd->{'sql'}, undef);

# Run it
$cmd = $dbh->prepare($cmd->{'sql'});
if (!$cmd) {
	print &text('srun_eprepare', $dbh->errstr),"<p>\n";
	}
elsif (!$cmd->execute(@$args)) {
	print &text('srun_eexecute', $dbh->errstr),"<p>\n";
	}
else {
	# Show results
	if (@titles = @{$cmd->{'NAME'}}) {
		print &ui_columns_start(\@titles);

		# Show results
		while(my @r = $cmd->fetchrow()) {
			print &ui_columns_row(\@r);
			}

		print &ui_columns_end();
		$cmd->finish();
		}
	else {
		$r = $cmd->finish();
		print &text('srun_none', $r),"<p>\n";
		}
	}

&ui_print_footer("", $text{'index_return'});

