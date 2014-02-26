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
local %smap = map { $_->{'id'}, $_ } &list_servers();
local $hdir = "$module_config_directory/hosts";
opendir(DIR, $hdir);
local ($h, @rv);
foreach $h (readdir(DIR)) {
	next if ($h eq "." || $h eq ".." || !-d "$hdir/$h");
	local %host = ( 'id', $h );
	next if (!$smap{$h});   # underlying server was deleted
	opendir(UDIR, "$hdir/$h");
	foreach $f (readdir(UDIR)) {
		if ($f =~ /^(\S+)\.user$/) {
			local %user;
			&read_file("$hdir/$h/$f", \%user);
			push(@{$host{'users'}}, \%user);
			}
		elsif ($f =~ /^(\S+)\.group$/) {
			local %group;
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
local $hdir = "$module_config_directory/hosts";
local %oldfile;
mkdir($hdir, 0700);
if (-d "$hdir/$_[0]->{'id'}") {
	opendir(DIR, "$hdir/$_[0]->{'id'}");
	map { $oldfile{$_}++ } readdir(DIR);
	closedir(DIR);
	}
else {
	mkdir("$hdir/$_[0]->{'id'}", 0700);
	}
foreach $u (@{$_[0]->{'users'}}) {
	&write_file("$hdir/$_[0]->{'id'}/$u->{'user'}.user", $u);
	delete($oldfile{"$u->{'user'}.user"});
	}
foreach $g (@{$_[0]->{'groups'}}) {
	&write_file("$hdir/$_[0]->{'id'}/$g->{'group'}.group", $g);
	delete($oldfile{"$g->{'group'}.group"});
	}
unlink(map { "$hdir/$_[0]->{'id'}/$_" } keys %oldfile);
}

# delete_useradmin_host(&host)
sub delete_useradmin_host
{
system("rm -rf '$module_config_directory/hosts/$_[0]->{'id'}'");
}

# list_servers()
# Returns a list of all servers from the webmin servers module that can be
# managed, plus this server
sub list_servers
{
local @servers = &servers::list_servers_sorted();
return ( &servers::this_server(), grep { $_->{'user'} } @servers );
}

# auto_home_dir(base, username)
# Returns an automatically generated home directory, and creates needed
# parent dirs
sub auto_home_dir
{
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
return $_[0]->{'desc'} ? $_[0]->{'desc'} : $_[0]->{'host'};
}

# supports_gothers(&server)
# Returns 1 if some server supports group syncing, 0 if not
sub supports_gothers
{
local $vers = $remote_server_version{$_[0]->{'host'}} ||
	      &remote_foreign_call($_[0]->{'host'}, "useradmin",
				  "get_webmin_version");
return $vers >= 1.090;
}

# create_on_input(desc, [no-donthave], [multiple])
sub create_on_input
{
local @hosts = &list_useradmin_hosts();
local @servers = &list_servers();
if ($_[0]) {
	print "<tr> <td><b>$_[0]</b></td>\n";
	print "<td colspan=2>\n";
	}
if ($_[2]) {
	print "<select name=server size=5 multiple>\n";
	}
else {
	print "<select name=server>\n";
	}
print "<option value=-1>$text{'uedit_all'}</option>\n";
print "<option value=-2>$text{'uedit_donthave'}</option>\n" if (!$_[1]);
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
                &text('uedit_group', $g->{'name'}),"</option>\n" if ($found);
        }
print "</select>\n";
if ($_[0]) {
	print "</td> </tr>\n";
	}
}

# create_on_parse(prefix, &already, name, [no-print])
sub create_on_parse
{
local @allhosts = &list_useradmin_hosts();
local @servers = &list_servers();
local @hosts;
local $server;
foreach $server (split(/\0/, $in{'server'})) {
	if ($server == -2) {
		# Check who has it already
		local %already = map { $_->{'id'}, 1 } @{$_[1]};
		push(@hosts, grep { !$already{$_->{'id'}} } @allhosts);
		print "<b>",&text($_[0].'3', $_[2]),"</b><p>\n" if (!$_[3]);
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
		local ($onehost) = grep { $_->{'id'} == $server } @allhosts;
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

