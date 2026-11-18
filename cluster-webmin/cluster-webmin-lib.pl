# cluster-webmin-lib.pl
# Common functions for managing webmin installs across a cluster

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
&foreign_require("servers", "servers-lib.pl");

# list_cluster_users(server)
# List accounts eligible for Cluster management. Require the remote ACL library
# first. Filter on the server so older peers need no new API or extra RPC calls.
sub list_cluster_users
{
my ($server) = @_;
# Return an array reference because fast RPC evaluates code in scalar context.
my $users = &remote_eval($server, "acl", '
	[ grep {
		my %acl = &get_module_acl($_->{"name"}, "", 1, 1);
		!$acl{"api_only"};
		} &list_users() ];
	');
return $users ? @$users : ( );
}

# list_webmin_hosts()
# Returns a list of all hosts whose webmin modules are being managed
sub list_webmin_hosts
{
local %smap = map { $_->{'id'}, $_ } &list_servers();
local $hdir = "$module_config_directory/hosts";
opendir(DIR, $hdir);
local ($h, @rv);
foreach $h (readdir(DIR)) {
	next if ($h eq "." || $h eq ".." || !-d "$hdir/$h");
	local %host = ( 'id', $h );
	next if (!$smap{$h});   # underlying server was deleted
	local $f;
	opendir(MDIR, "$hdir/$h");
	foreach $f (readdir(MDIR)) {
		if ($f =~ /^(\S+)\.mod$/) {
			local %mod;
			&read_file("$hdir/$h/$f", \%mod);
			push(@{$host{'modules'}}, \%mod);
			}
		elsif ($f =~ /^(\S+)\.theme$/) {
			local %theme;
			&read_file("$hdir/$h/$f", \%theme);
			push(@{$host{'themes'}}, \%theme);
			}
		elsif ($f =~ /^(\S+)\.user$/) {
			local %user;
			&read_file("$hdir/$h/$f", \%user);
			$user{'modules'} = [ split(/\s+/, $user{'modules'}) ];
			$user{'ownmods'} = [ split(/\s+/, $user{'ownmods'}) ];
			$user{'olds'} = [ split(/\s+/, $user{'olds'}) ];
			push(@{$host{'users'}}, \%user);
			}
		elsif ($f =~ /^(\S+)\.group$/) {
			local %group;
			&read_file("$hdir/$h/$f", \%group);
			$group{'modules'} = [ split(/\s+/, $group{'modules'}) ];
			$group{'ownmods'} = [ split(/\s+/, $group{'ownmods'}) ];
			$group{'members'} = [ split(/\s+/, $group{'members'}) ];
			push(@{$host{'groups'}}, \%group);
			}
		elsif ($f eq "webmin") {
			&read_file("$hdir/$h/$f", \%host);
			}
		}
	closedir(MDIR);
	push(@rv, \%host);
	}
closedir(DIR);
return @rv;
}

# save_webmin_host(&host)
# Writes the cached modules, themes, users and groups of a managed server.
# Records whose name cannot be used as a file name are skipped, so one bad
# record does not stop the others from being cached.
sub save_webmin_host
{
local $hdir = "$module_config_directory/hosts";
local %oldfile;
&servers::cache_path_component($_[0]->{'id'}) || &error($text{'host_einvalid'});
mkdir($hdir, 0700);
if (-d "$hdir/$_[0]->{'id'}") {
	opendir(DIR, "$hdir/$_[0]->{'id'}");
	map { $oldfile{$_}++ } readdir(DIR);
	closedir(DIR);
	}
else {
	mkdir("$hdir/$_[0]->{'id'}", 0700);
	}
local $m;
foreach $m (@{$_[0]->{'modules'}}) {
	local $cm = &clean_cache_record($m, 'dir') || next;
	&write_file("$hdir/$_[0]->{'id'}/$cm->{'dir'}.mod", $cm);
	delete($oldfile{"$cm->{'dir'}.mod"});
	}
foreach $m (@{$_[0]->{'themes'}}) {
	local $cm = &clean_cache_record($m, 'dir') || next;
	&write_file("$hdir/$_[0]->{'id'}/$cm->{'dir'}.theme", $cm);
	delete($oldfile{"$cm->{'dir'}.theme"});
	}
foreach $m (@{$_[0]->{'users'}}) {
	next if (ref($m) ne 'HASH');
	local %u = %$m;
	$u{'modules'} = join(" ", @{$u{'modules'}});
	$u{'ownmods'} = join(" ", @{$u{'ownmods'}});
	$u{'olds'} = join(" ", @{$u{'olds'}});
	local $cu = &clean_cache_record(\%u, 'name') || next;
	&write_file("$hdir/$_[0]->{'id'}/$cu->{'name'}.user", $cu);
	delete($oldfile{"$cu->{'name'}.user"});
	}
foreach $m (@{$_[0]->{'groups'}}) {
	next if (ref($m) ne 'HASH');
	local %g = %$m;
	$g{'modules'} = join(" ", @{$g{'modules'}});
	$g{'ownmods'} = join(" ", @{$g{'ownmods'}});
	$g{'members'} = join(" ", @{$g{'members'}});
	local $cg = &clean_cache_record(\%g, 'name') || next;
	&write_file("$hdir/$_[0]->{'id'}/$cg->{'name'}.group", $cg);
	delete($oldfile{"$cg->{'name'}.group"});
	}
local %webmin = %{$_[0]};
delete($webmin{'modules'});
delete($webmin{'themes'});
delete($webmin{'users'});
delete($webmin{'groups'});
delete($webmin{'id'});
&write_file("$hdir/$_[0]->{'id'}/webmin", &clean_cache_record(\%webmin));
delete($oldfile{"webmin"});
unlink(map { "$hdir/$_[0]->{'id'}/$_" } keys %oldfile);
}

# clean_cache_record(&record, [name-field])
# Returns a copy of a record from a managed server that is safe to write with
# write_file, or undef if the record is not a hash or its name field is not a
# safe file name. Keys that would break the file format are dropped. Trailing
# line breaks are removed from values, and other line breaks become spaces.
sub clean_cache_record
{
my ($rec, $field) = @_;
return undef if (ref($rec) ne 'HASH' ||
		 $field && !&servers::cache_path_component($rec->{$field}));
my %clean;
foreach my $k (keys %$rec) {
	# Skip keys that cannot be read back from the cache file
	next if ($k eq '' || $k =~ /[=\r\n\0]/);
	my $v = $rec->{$k};
	if (defined($v) && !ref($v)) {
		$v =~ s/[\r\n\0]+$//;
		$v =~ s/[\r\n\0]+/ /g;
		}
	$clean{$k} = $v;
	}
return \%clean;
}

# delete_webmin_host(&host)
sub delete_webmin_host
{
&servers::cache_path_component($_[0]->{'id'}) || &error($text{'host_einvalid'});
system("rm -rf ".quotemeta("$module_config_directory/hosts/$_[0]->{'id'}"));
}

# list_servers()
# Returns a list of all servers from the webmin servers module that can be
# managed, plus this server
sub list_servers
{
local @servers = &servers::list_servers_sorted();
return ( &servers::this_server(), grep { $_->{'user'} } @servers );
}

# server_name(&server)
sub server_name
{
return ($_[0]->{'id'} == 0 ? &get_system_hostname() : $_[0]->{'host'}).
       ($_[0]->{'desc'} ? " (".$_[0]->{'desc'}.")" : "");
}

# all_modules(&hosts)
sub all_modules
{
local (%done, $u, %descc);
local @uniq = grep { !$done{$_->{'dir'}}++ } map { @{$_->{'modules'}} } @{$_[0]};
map { $descc{$_->{'desc'}}++ } @uniq;
foreach $u (@uniq) {
	$u->{'desc'} .= " ($u->{'dir'})" if ($descc{$u->{'desc'}} > 1);
	}
return sort { $a->{'desc'} cmp $b->{'desc'} } @uniq;
}

# all_themes(&hosts)
sub all_themes
{
local %done;
return sort { $a->{'desc'} cmp $b->{'desc'} }
	grep { !$done{$_->{'dir'}}++ }
	 map { @{$_->{'themes'}} } @{$_[0]};
}

# all_groups(&hosts)
sub all_groups
{
local %done;
return sort { $a->{'name'} cmp $b->{'name'} }
	grep { !$done{$_->{'name'}}++ }
	 map { @{$_->{'groups'}} } @{$_[0]};
}

# all_users(&hosts)
sub all_users
{
local %done;
return sort { $a->{'name'} cmp $b->{'name'} }
	grep { !$done{$_->{'name'}}++ }
	 map { @{$_->{'users'}} } @{$_[0]};
}

# create_on_input(desc, [no-donthave], [no-have], [multiple], [colspan])
sub create_on_input
{
local @hosts = &list_webmin_hosts();
local @servers = &list_servers();
if ($_[0]) {
	print "<tr> <td><b>$_[0]</b></td>\n";
	my $colspan = "colspan=$_[4]" if ($_[4]);
	print "<td $colspan>\n";
	}
if ($_[3]) {
	print "<select name=server size=5 multiple>\n";
	}
else {
	print "<select name=server>\n";
	}
print "<option value=-1>$text{'user_all'}</option>\n";
print "<option value=-2>$text{'user_donthave'}</option>\n" if (!$_[1]);
print "<option value=-3>$text{'user_have'}</option>\n" if (!$_[2]);
local @groups = &servers::list_all_groups(\@servers);
local $h;
foreach $h (@hosts) {
        local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
	if ($s) {
		print "<option value='$s->{'id'}'>",
			$s->{'desc'} ? $s->{'desc'} : $s->{'host'},"</option>\n";
		$gothost{$s->{'host'}}++;
		}
        }
local $g;
foreach $g (@groups) {
        local ($found, $m);
        foreach $m (@{$g->{'members'}}) {
                ($found++, last) if ($gothost{$m});
                }
        print "<option value='group_$g->{'name'}'>",
                &text('user_ofgroup', $g->{'name'}),"</option>\n" if ($found);
        }
print "</select>\n";
if ($_[0]) {
	print "</td> </tr>\n";
	}
}

# create_on_parse(prefix, &already, name, [no-print])
sub create_on_parse
{
local @allhosts = &list_webmin_hosts();
local @servers = &list_servers();
local @hosts;
local $server;
foreach $server (split(/\0/, $in{'server'})) {
	if ($server == -2) {
		# Install on hosts that don't have it
		local %already = map { $_->{'id'}, 1 } @{$_[1]};
		push(@hosts, grep { !$already{$_->{'id'}} } @allhosts);
		print "<b>",&text($_[0].'3', $_[2]),"</b><p>\n" if (!$_[3]);
		}
	elsif ($server == -3) {
		# Install on hosts that do have it
		local %already = map { $_->{'id'}, 1 } @{$_[1]};
		push(@hosts, grep { $already{$_->{'id'}} } @allhosts);
		print "<b>",&text($_[0].'6', $_[2]),"</b><p>\n" if (!$_[3]);
		}
	elsif ($server =~ /^group_(.*)/) {
		# Install on members of some group
		local ($group) = grep { $_->{'name'} eq $1 }
				      &servers::list_all_groups(\@servers);
		push(@hosts, grep { local $hid = $_->{'id'};
				local ($s) = grep { $_->{'id'} == $hid } @servers;
				&indexof($s->{'host'}, @{$group->{'members'}}) >= 0 }
			      @allhosts);
		print "<b>",&text($_[0].'4', $_[2], $group->{'name'}),
		      "</b><p>\n" if (!$_[3]);
		}
	elsif ($server != -1) {
		# Just install on one host
		local ($onehost) = grep { $_->{'id'} == $server }
					@allhosts;
		push(@hosts, $onehost);
		local ($s) = grep { $_->{'id'} == $onehost->{'id'} } @servers;
		print "<b>",&text($_[0].'5', $_[2],
				  &server_name($s)),"</b><p>\n" if (!$_[3]);
		}
	else {
		# Installing on every host
		push(@hosts, @allhosts);
		print "<b>",&text($_[0], join(" ", @names)),
		      "</b><p>\n" if (!$_[3]);
		}
	}
return &unique(@hosts);
}

1;

