# cluster-useradmin-lib.pl
# common functions for managing users across a cluster

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
&foreign_require("servers", "servers-lib.pl");
%useradmin_text = &load_language("useradmin");
%text = ( %useradmin_text, %text );
%uconfig = &foreign_config("useradmin");

# list_useradmin_hosts()
# Returns a list of all hosts whose users are being managed by this module
sub list_useradmin_hosts
{
my %smap = map { $_->{'id'}, $_ } &list_servers();
my $hdir = "$module_config_directory/hosts";
my @rv;
opendir(DIR, $hdir) || return ();
foreach my $h (readdir(DIR)) {
	next if ($h eq "." || $h eq ".." || !-d "$hdir/$h");
	my %host = ( 'id', $h );
	next if (!$smap{$h});   # underlying server was deleted
	opendir(UDIR, "$hdir/$h");
	foreach $f (readdir(UDIR)) {
		if ($f =~ /^(\S+)\.user$/) {
			my %user;
			&read_file("$hdir/$h/$f", \%user);
			push(@{$host{'users'}}, \%user);
			}
		elsif ($f =~ /^(\S+)\.group$/) {
			my %group;
			&read_file("$hdir/$h/$f", \%group);
			push(@{$host{'groups'}}, \%group);
			}
		}
	closedir(UDIR);
	push(@rv, \%host);
	}
closedir(DIR);
return @rv;
}

# save_useradmin_host(&host)
sub save_useradmin_host
{
my ($host) = @_;
my $hdir = "$module_config_directory/hosts";
my %oldfile;
mkdir($hdir, 0700);
if (-d "$hdir/$host->{'id'}") {
	opendir(DIR, "$hdir/$host->{'id'}");
	%oldfile = map { $_, 1 } readdir(DIR);
	closedir(DIR);
	}
else {
	mkdir("$hdir/$host->{'id'}", 0700);
	}
foreach my $u (@{$host->{'users'}}) {
	&write_file("$hdir/$host->{'id'}/$u->{'user'}.user", $u);
	delete($oldfile{"$u->{'user'}.user"});
	}
foreach my $g (@{$host->{'groups'}}) {
	&write_file("$hdir/$host->{'id'}/$g->{'group'}.group", $g);
	delete($oldfile{"$g->{'group'}.group"});
	}
unlink(map { "$hdir/$host->{'id'}/$_" } keys %oldfile);
}

# delete_useradmin_host(&host)
sub delete_useradmin_host
{
my ($host) = @_;
&unlink_file("$module_config_directory/hosts/$host->{'id'}");
}

# list_servers()
# Returns a list of all servers from the webmin servers module that can be
# managed, plus this server
sub list_servers
{
my @servers = &servers::list_servers_sorted();
return ( &servers::this_server(), grep { $_->{'user'} } @servers );
}

# auto_home_dir(base, username)
# Returns an automatically generated home directory, and creates needed
# parent dirs
sub auto_home_dir
{
my ($base, $user) = @_;
if ($uconfig{'home_style'} == 0) {
	return $_[0]."/".$_[1];
	}
elsif ($uconfig{'home_style'} == 1) {
	return $_[0]."/".substr($_[1], 0, 1)."/".$_[1];
	}
elsif ($uconfig{'home_style'} == 2) {
	return $_[0]."/".substr($_[1], 0, 1)."/".
	       substr($_[1], 0, 2)."/".$_[1];
	}
elsif ($uconfig{'home_style'} == 3) {
	return $_[0]."/".substr($_[1], 0, 1)."/".
	       substr($_[1], 1, 1)."/".$_[1];
	}
}

# server_name(&server)
sub server_name
{
my ($server) = @_;
my @w;
push(@w, $server->{'host'} || &get_system_hostname());
push(@w, "(".$server->{'desc'}.")") if ($server->{'desc'});
return join(" ", @w);
}

# supports_gothers(&server)
# Returns 1 if some server supports group syncing, 0 if not
sub supports_gothers
{
my ($server) = @_;
my $vers = $remote_server_version{$server->{'host'}} ||
	   &remote_foreign_call($server->{'host'}, "useradmin",
				"get_webmin_version");
return $vers >= 1.090;
}

# create_on_input([no-donthave], [multiple])
# Returns a selector for a server or group to create users on
sub create_on_input
{
my ($nodont, $mul) = @_;
my @hosts = &list_useradmin_hosts();
my @servers = &list_servers();
my @opts = ( [ -1, $text{'uedit_all'} ] );
push(@opts, [ -2, $text{'uedit_donthave'} ] ) if (!$nodont);
my @groups = &servers::list_all_groups(\@servers);
my $h;
foreach $h (@hosts) {
        my ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
	if ($s) {
		push(@opts, [ $s->{'id'}, &server_name($s) ]);
		$gothost{$s->{'host'}}++;
		}
        }
foreach my $g (@groups) {
        my ($found, $m);
        foreach $m (@{$g->{'members'}}) {
                $found++ if ($gothost{$m});
                }
	push(@opts, [ "group_$g->{'name'}",
		      &text('uedit_group', $g->{'name'}) ]) if ($found);
        }
return &ui_select("server", undef, \@opts, $mul ? 5 : 1, $mul);
}

# create_on_parse(prefix, &already, name, [no-print])
# Returns a list of selected hosts from an input created by create_on_input
sub create_on_parse
{
my ($pfx, $already, $name, $noprint) = @_;
my @allhosts = &list_useradmin_hosts();
my @servers = &list_servers();
my @hosts;
my $server;
foreach $server (split(/\0/, $in{'server'})) {
	if ($server == -2) {
		# Check who has it already
		my %already = map { $_->{'id'}, 1 } @$already;
		push(@hosts, grep { !$already{$_->{'id'}} } @allhosts);
		print "<b>",&text($pfx.'3', $name),"</b><p>\n" if (!$noprint);
		}
	elsif ($server =~ /^group_(.*)/) {
		# Install on members of some group
		my ($group) = grep { $_->{'name'} eq $1 }
				      &servers::list_all_groups(\@servers);
		push(@hosts, grep { my $hid = $_->{'id'};
				my ($s) = grep { $_->{'id'} == $hid } @servers;
				&indexof($s->{'host'}, @{$group->{'members'}}) >= 0 }
			      @allhosts);
		print "<b>",&text($pfx.'4', $name, $group->{'name'}),
		      "</b><p>\n" if (!$noprint);
		}
	elsif ($server != -1) {
		# Just install on one host
		my ($onehost) = grep { $_->{'id'} == $server } @allhosts;
		push(@hosts, $onehost);
		my ($s) = grep { $_->{'id'} == $onehost->{'id'} } @servers;
		print "<b>",&text($pfx.'5', $name,
				  &server_name($s)),"</b><p>\n" if (!$noprint);
		}
	else {
		# Installing on every host
		push(@hosts, @allhosts);
		print "<b>",&text($pfx, join(" ", @names)),
		      "</b><p>\n" if (!$noprint);
		}
	}
return &unique(@hosts);
}

1;

