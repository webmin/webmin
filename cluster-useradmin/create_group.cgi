#!/usr/local/bin/perl
# create_group.cgi
# Creates a new group on all servers

require './cluster-useradmin-lib.pl';
use Time::Local;
&error_setup($text{'gsave_err'});
&ReadParse();
@hosts = &list_useradmin_hosts();
@servers = &list_servers();

# Strip out \n characters in inputs
$in{'group'} =~ s/\r|\n//g;
$in{'pass'} =~ s/\r|\n//g;
$in{'encpass'} =~ s/\r|\n//g;
$in{'gid'} =~ s/\r|\n//g;

# check group name
$in{'group'} =~ /^[^:\t]+$/ ||
	&error(&text('gsave_ebadname', $in{'group'}));
$uconfig{'max_length'} && length($in{'group'}) > $uconfig{'max_length'} &&
	&error(&text('gsave_elength', $uconfig{'max_length'}));

$| = 1;
&ui_print_header(undef, $text{'gedit_title2'}, "");

# Work out which hosts to create on
@already = grep { local ($alr) = grep { $_->{'group'} eq $in{'group'} }
				    @{$_->{'groups'}};
		  $alr } @hosts;
@hosts = &create_on_parse("gsave_header", \@already, $in{'group'});

# Check for group name clash
foreach $h (@hosts) {
	local ($og) = grep { $_->{'group'} eq $in{'group'} } @{$h->{'groups'}};
	&error(&text('gsave_einuse', $in{'group'})) if ($og);
	}
$group{'group'} = $in{'group'};

# Validate and save inputs
$in{'gid'} =~ /^[0-9]+$/ || &error(&text('gsave_egid', $in{'gid'}));
@mems = split(/\s+/, $in{members});
$group{'members'} = join(',', @mems);
$group{'gid'} = $in{'gid'};

$salt = chr(int(rand(26))+65) . chr(int(rand(26))+65);
if ($in{'passmode'} == 0) { $group{'pass'} = ""; }
elsif ($in{'passmode'} == 1) { $group{'pass'} = $in{'encpass'}; }
elsif ($in{'passmode'} == 2) { $group{'pass'} = &unix_crypt($in{'pass'}, $salt); }

# Setup error handler for down hosts
sub add_error
{
$add_error_msg = join("", @_);
}
&remote_error_setup(\&add_error);

foreach $host (@hosts) {
	$add_error_msg = undef;
	local ($serv) = grep { $_->{'id'} == $host->{'id'} } @servers;
	print "<b>",&text('gsave_con', $serv->{'desc'} ? $serv->{'desc'} :
				       $serv->{'host'}),"</b><p>\n";
	print "<ul>\n";
	&remote_foreign_require($serv->{'host'}, "useradmin", "user-lib.pl");
	if ($add_error_msg) {
		# Host is down ..
		print &text('gsave_failed', $add_error_msg),"<p>\n";
		print "</ul>\n";
		next;
		}

	# Run the pre-change command
	&remote_eval($serv->{'host'}, "useradmin", <<EOF
\$ENV{'USERADMIN_GROUP'} = '$group{'group'}';
\$ENV{'USERADMIN_ACTION'} = 'CREATE_GROUP';
EOF
	);
	$merr = &remote_foreign_call($serv->{'host'}, "useradmin",
				     "making_changes");
	if (defined($merr)) {
		print &text('usave_emaking', "<tt>$merr</tt>"),"<p>\n";
		print "</ul>\n";
		next;
		}

	# Save group details
	print "$text{'gsave_create'}<br>\n";
	&remote_foreign_call($serv->{'host'}, "useradmin",
			     "create_group", \%group);
	print "$text{'udel_done'}<p>\n";

	# Run post-change command
	&remote_foreign_call($serv->{'host'}, "useradmin", "made_changes");

	if ($in{'others'}) {
		if (&supports_gothers($serv)) {
			# Create in other modules on the server
			print "$text{'usave_others'}<br>\n";
			&remote_foreign_call($serv->{'host'}, "useradmin",
				     "other_modules", "useradmin_create_group",
				     \%group);
			print "$text{'udel_done'}<p>\n";
			}
		else {
			# Group syncing not supported
			print "$text{'gsave_nosync'}<p>\n";
			}
		}

	# Update host
	push(@{$host->{'groups'}}, \%group);
	&save_useradmin_host($host);
	print "</ul>\n";
	}
&webmin_log("create", "group", $group{'group'}, \%group);

&ui_print_footer("", $text{'index_return'});

