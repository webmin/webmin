# Functions for FreeBSD ports / package management

sub list_update_system_commands
{
return ( "pkg_add" );
}

# update_system_install([package], [&in])
# Install a named package, by buiding the port
sub update_system_install
{
my ($update, $in) = @_;
$update ||= $in{'update'};
my (@rv, @newpacks);
my @want = split(/\s+/, $update);
print "<b>",&text('ports_install', "<tt>$update</tt>"),"</b><p>\n";
print "<pre>";
my $err = 0;
foreach my $w (@want) {
	my $cmd = "cd /usr/ports/$w && make package";
	&additional_log('exec', undef, $cmd);
	$ENV{'BATCH'} = 1;
	&open_execute_command(CMD, "$cmd </dev/null", 2);
	while(<CMD>) {
		s/\r|\n//g;
		if (/Building\s+package\s+(\S+)/) {
			push(@rv, $2);
			}
		}
	print &html_escape($_."\n");
	close(CMD);
	$err++ if ($?);
	}
print "</pre>\n";
if ($err) {
	print "<b>$text{'ports_failed'}</b><p>\n";
	return ( );
	}
else {
	print "<b>$text{'ports_ok'}</b><p>\n";
	return &unique(@rv);
	}
}

# update_system_search(text)
# Returns a list of packages matching some search
sub update_system_search
{
my ($search) = @_;
&clean_language();
my $cmd = "cd /usr/ports && make search key=".quotemeta($search);
my $out = &backquote_command("$cmd 2>&1 </dev/null");
if ($out =~ /make\s+fetchindex/) {
	&execute_command("cd /usr/ports && make fetchindex");
	$out = &backquote_command("$cmd 2>&1 </dev/null");
	}
foreach my $line (split(/\r?\n/, $out)) {
	if ($line =~ /Path:\s+\/usr\/ports\/(\S+)/) {
		my $p = { 'name' => $1 };
		push(@rv, $1);
		}
	elsif ($line =~ /Info:\s+(.*)/ && @rv) {
		$rv[$#rv]->{'desc'} = $1;
		}
	}
&reset_environment();
return @rv;
}



1;
