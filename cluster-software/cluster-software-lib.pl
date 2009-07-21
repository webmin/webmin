# cluster-software-lib.pl
# common functions for installing packages across a cluster
# XXX refresh all packages after installing

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
&foreign_require("servers", "servers-lib.pl");
&foreign_require("software", "software-lib.pl");
$parallel_max = 20;
%access = &get_module_acl();

# list_software_hosts()
# Returns a list of all hosts whose software is being managed by this module
sub list_software_hosts
{
local @rv;
local %smap = map { $_->{'id'}, $_ } &list_servers();
local $hdir = "$module_config_directory/hosts";
opendir(DIR, $hdir);
foreach $h (readdir(DIR)) {
	next if ($h =~ /\.host$/ || $h eq '.' || $h eq '..');
	local %host = ( 'id', $h );
	next if (!$smap{$h});	# underlying server was deleted
	opendir(PDIR, "$hdir/$h") || next;
	foreach $p (readdir(PDIR)) {
		next if ($p eq "." || $p eq "..");
		local %pkg;
		&read_file("$hdir/$h/$p", \%pkg);
		push(@{$host{'packages'}}, \%pkg);
		}
	closedir(PDIR);
	&read_file("$hdir/$h.host", \%host);
	push(@rv, \%host);
	}
closedir(DIR);
return @rv;
}

# save_software_host(&host)
# Add or update a managed host with it's package list
sub save_software_host
{
local $hdir = "$module_config_directory/hosts";
mkdir($hdir, 0700);
if (-d "$hdir/$_[0]->{'id'}") {
	opendir(DIR, "$hdir/$_[0]->{'id'}");
	foreach $f (readdir(DIR)) {
		unlink("$hdir/$_[0]->{'id'}/$f");
		}
	closedir(DIR);
	}
else {
	mkdir("$hdir/$_[0]->{'id'}", 0700);
	}
foreach $p (@{$_[0]->{'packages'}}) {
	local $pname = $p->{'name'};
	$pname =~ s/\//_/g;
	&write_file("$hdir/$_[0]->{'id'}/$pname", $p);
	}
local %h = %{$_[0]};
delete($h{'packages'});
&write_file("$hdir/$_[0]->{'id'}.host", \%h);
}

# delete_software_host(&host)
sub delete_software_host
{
&unlink_file("$module_config_directory/hosts/$_[0]->{'id'}.host");
&unlink_file("$module_config_directory/hosts/$_[0]->{'id'}");
}

# list_servers()
# Returns a list of all servers from the webmin servers module that can be
# managed, plus this server
sub list_servers
{
local @servers = &servers::list_servers_sorted();
return ( &servers::this_server(), grep { $_->{'user'} } @servers );
}

# host_to_server(&host|id)
sub host_to_server
{
local $id = ref($_[0]) ? $_[0]->{'id'} : $_[0];
local ($serv) = grep { $_->{'id'} eq $id } &list_servers();
return $serv;
}

# server_name(&server)
sub server_name
{
return $_[0]->{'desc'} || $_[0]->{'realhost'} || $_[0]->{'host'};
}

# get_heiropen(hostid)
# Returns an array of open categories
sub get_heiropen
{
open(HEIROPEN, "$module_config_directory/heiropen.$_[0]");
local @heiropen = <HEIROPEN>;
chop(@heiropen);
close(HEIROPEN);
return @heiropen;
}

# save_heiropen(&heir, hostid)
sub save_heiropen
{
&open_tempfile(HEIR, ">$module_config_directory/heiropen.$_[1]");
foreach $h (@{$_[0]}) {
	&print_tempfile(HEIR, $h,"\n");
	}
&close_tempfile(HEIR);
}

# create_on_input(desc, [no-donthave], [no-have])
sub create_on_input
{
local @hosts = &list_software_hosts();
local @servers = &list_servers();
local @opts;
push(@opts, [ -1, $text{'edit_all'} ]);
push(@opts, [ -2, $text{'edit_donthave'} ]) if (!$_[1]);
push(@opts, [ -3, $text{'edit_have'} ]) if (!$_[2]);
local @groups = &servers::list_all_groups(\@servers);
local $h;
foreach $h (@hosts) {
        local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
	if ($s) {
		push(@opts, [ $s->{'id'},
			$s->{'desc'} || $s->{'realhost'} || $s->{'host'} ]);
		$gothost{$s->{'host'}}++;
		}
        }
local $g;
foreach $g (@groups) {
        local ($found, $m);
        foreach $m (@{$g->{'members'}}) {
                ($found++, last) if ($gothost{$m});
                }
	push(@opts, [ "group_$g->{'name'}",
		      &text('edit_group', $g->{'name'}) ]) if ($found);
        }
local $sel = &ui_select("server", undef, \@opts);
if ($_[0]) {
	print &ui_table_row($_[0], $sel);
	}
else {
	print $sel;
	}
}

# create_on_parse(prefix, &already, name)
sub create_on_parse
{
local @hosts = &list_software_hosts();
local @servers = &list_servers();
if ($in{'server'} == -2) {
	# Install on hosts that don't have it
	local %already = map { $_->{'id'}, 1 } @{$_[1]};
	@hosts = grep { !$already{$_->{'id'}} } @hosts;
        print "<b>",&text($_[0].'3', $_[2]),"</b><p>\n";
        }
elsif ($in{'server'} == -3) {
	# Install on hosts that do have it
	local %already = map { $_->{'id'}, 1 } @{$_[1]};
	@hosts = grep { $already{$_->{'id'}} } @hosts;
        print "<b>",&text($_[0].'6', $_[2]),"</b><p>\n";
        }
elsif ($in{'server'} =~ /^group_(.*)/) {
        # Install on members of some group
        local ($group) = grep { $_->{'name'} eq $1 }
                              &servers::list_all_groups(\@servers);
        @hosts = grep { local $hid = $_->{'id'};
                        local ($s) = grep { $_->{'id'} == $hid } @servers;
                        &indexof($s->{'host'}, @{$group->{'members'}}) >= 0 }
                      @hosts;
        print "<b>",&text($_[0].'4', $_[2], $group->{'name'}),
              "</b><p>\n";
        }
elsif ($in{'server'} != -1) {
        # Just install on one host
        @hosts = grep { $_->{'id'} == $in{'server'} } @hosts;
        local ($s) = grep { $_->{'id'} == $hosts[0]->{'id'} } @servers;
        print "<b>",&text($_[0].'5', $_[2],
                          &server_name($s)),"</b><p>\n";
        }
else {
        # Installing on every host
        print "<b>",&text($_[0], join(" ", @names)),"</b><p>\n";
        }
return @hosts;
}

# Setup error handler for down hosts
sub add_error
{
$add_error_msg = join("", @_);
}

# add_managed_host(&server)
# Adds a new system to this module for management, and returns a status code
# (0 or 1) and error or information message
sub add_managed_host
{
local ($s) = @_;

&remote_error_setup(\&add_error);

# Get the packages for each host
local %sconfig = &foreign_config("software");
$add_error_msg = undef;
local $host = { 'id' => $s->{'id'} };
local $soft = &remote_foreign_check($s->{'host'}, "software");
if ($add_error_msg) {
	return (0, $add_error_msg);
	}
if (!$soft) {
	return (0, &text('add_echeck', $s->{'host'}));
	}
&remote_foreign_require($s->{'host'}, "software", "software-lib.pl");
local $rconfig = &remote_foreign_config($s->{'host'}, "software");
#if ($rconfig->{'package_system'} ne $sconfig{'package_system'}) {
#	return (0, &text('add_esystem', $s->{'host'}));
#	}
$host->{'package_system'} = $rconfig->{'package_system'};
local $gconfig = &remote_foreign_config($s->{'host'}, undef);
foreach $g ('os_type', 'os_version',
	    'real_os_type', 'real_os_version') {
	$host->{$g} = $gconfig->{$g};
	}
local $n = &remote_foreign_call($s->{'host'}, "software",
				"list_packages");
local $packages = &remote_eval($s->{'host'}, "software", "\\%packages");
for(my $i=0; $i<$n; $i++) {
	push(@{$host->{'packages'}},
	     { 'name' => $packages->{$i,'name'},
	       'class' => $packages->{$i,'class'},
	       'desc' => $packages->{$i,'desc'},
	       'version' => $packages->{$i,'version'},
	       'nouninstall' => $packages->{$i,'nouninstall'},
	       'nolist' => $packages->{$i,'nolist'}, });
	}
&save_software_host($host);
return (1, &text('add_ok', &server_name($s), $n));
}

# refresh_packages(&hosts)
# Update the local cache with actual installed packages. Returns an array
# of either an error messages or two arrays of added and removed packages.
sub refresh_packages
{
local ($hosts) = @_;
local @servers = &list_servers();

# Setup error handler for down hosts
sub ref_error
{
$ref_error_msg = join("", @_);
}
&remote_error_setup(\&ref_error);

local $p = 0;
foreach my $h (@$hosts) {
	local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;

	local ($rh = "READ$p", $wh = "WRITE$p");
	pipe($rh, $wh);
	if (!fork()) {
		close($rh);
		if ($s) {
			# Refresh the list
			&remote_foreign_require($s->{'host'}, "software",
						"software-lib.pl");
			if ($ref_error_msg) {
				# Host is down ..
				print $wh &serialise_variable($ref_error_msg);
				exit;
				}
			local $gconfig = &remote_foreign_config($s->{'host'}, undef);
			foreach $g ('os_type', 'os_version',
				    'real_os_type', 'real_os_version') {
				$h->{$g} = $gconfig->{$g};
				}
			local @old = map { $_->{'name'} } @{$h->{'packages'}};
			undef($h->{'packages'});
			local $n = &remote_foreign_call($s->{'host'}, "software",
							"list_packages");
			local $packages = &remote_eval($s->{'host'}, "software",
						       "\\%packages");
			local @added;
			for($i=0; $i<$n; $i++) {
				next if (!$packages->{$i,'name'});
				push(@{$h->{'packages'}},
				     { 'name' => $packages->{$i,'name'},
				       'class' => $packages->{$i,'class'},
				       'desc' => $packages->{$i,'desc'},
				       'version' => $packages->{$i,'version'},
				       'nouninstall' => $packages->{$i,'nouninstall'},
				       'nolist' => $packages->{$i,'nolist'}, });
				$idx = &indexof($packages->{$i,'name'}, @old);
				if ($idx < 0) {
					push(@added, $packages->{$i,'name'});
					}
				else {
					splice(@old, $idx, 1);
					}
				}
			&save_software_host($h);
			$rv = [ \@added, \@old ];
			}
		else {
			# remove from managed list
			&delete_software_host($h);
			$rv = undef;
			}
		print $wh &serialise_variable($rv);
		close($wh);
		exit;
		}
	close($wh);
	$p++;
	}

# Read back results
$p = 0;
local @results;
foreach my $h (@hosts) {
	local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
	local $rh = "READ$p";
	local $line = <$rh>;
	local $rv = &unserialise_variable($line);
	close($rh);
	push(@results, $rv);
	$p++;
	}

return @results;
}

# same_package_system(&host)
# Returns 1 if some host is using the same package system as this master
sub same_package_system
{
local ($host) = @_;
return !$host->{'package_system'} ||
       $host->{'package_system'} eq $software::config{'package_system'};
}

1;

