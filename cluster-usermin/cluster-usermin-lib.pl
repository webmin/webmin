# cluster-usermin-lib.pl
# Common functions for managing usermin installs across a cluster

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
&foreign_require("servers", "servers-lib.pl");
&foreign_require("usermin", "usermin-lib.pl");

# list_usermin_hosts()
# Returns a list of all hosts whose usermin modules are being managed
sub list_usermin_hosts
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
		elsif ($f eq "usermin") {
			&read_file("$hdir/$h/$f", \%host);
			}
		}
	closedir(MDIR);
	push(@rv, \%host);
	}
closedir(DIR);
return @rv;
}

# save_usermin_host(&host)
sub save_usermin_host
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
local $m;
foreach $m (@{$_[0]->{'modules'}}) {
	&write_file("$hdir/$_[0]->{'id'}/$m->{'dir'}.mod", $m);
	delete($oldfile{"$m->{'dir'}.mod"});
	}
foreach $m (@{$_[0]->{'themes'}}) {
	&write_file("$hdir/$_[0]->{'id'}/$m->{'dir'}.theme", $m);
	delete($oldfile{"$m->{'dir'}.theme"});
	}
local %usermin = %{$_[0]};
delete($usermin{'modules'});
delete($usermin{'themes'});
delete($usermin{'id'});
&write_file("$hdir/$_[0]->{'id'}/usermin", \%usermin);
delete($oldfile{"usermin"});
unlink(map { "$hdir/$_[0]->{'id'}/$_" } keys %oldfile);
}

# delete_usermin_host(&host)
sub delete_usermin_host
{
system("rm -rf '$module_config_directory/hosts/$_[0]->{'id'}'");
}

# list_servers()
# Returns a list of all servers from the usermin servers module that can be
# managed, plus this server
sub list_servers
{
local @servers = &servers::list_servers_sorted();
return ( &servers::this_server(), grep { $_->{'user'} } @servers );
}

# server_name(&server)
sub server_name
{
return $_[0]->{'desc'} ? $_[0]->{'desc'} : $_[0]->{'host'};
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

# create_on_input(desc, [no-donthave], [no-have], [multiple])
sub create_on_input
{
local @hosts = &list_usermin_hosts();
local @servers = &list_servers();
if ($_[0]) {
	print "<tr> <td><b>$_[0]</b></td>\n";
	print "<td>\n";
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
local @allhosts = &list_usermin_hosts();
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

# get_usermin_text()
# Returns the text hash for Usermin, on this system
sub get_usermin_text
{
local %text;
local %miniserv;
&usermin::get_usermin_miniserv_config(\%miniserv);
local $root = $miniserv{'root'};
local %ugconfig;
&usermin::get_usermin_config(\%ugconfig);
local $ol = $ugconfig{'overlang'};
local $o;
local ($dir) = ($_[1] || "lang");

# Read global lang files
foreach $o (@lang_order_list) {
	local $ok = &read_file_cached("$root/$dir/$o", \%text);
	return () if (!$ok && $o eq $default_lang);
	}
if ($ol) {
	foreach $o (@lang_order_list) {
		&read_file_cached("$root/$ol/$o", \%text);
		}
	}
&read_file_cached("$usermin::config{'usermin_dir'}/custom-lang", \%text);

if ($_[0]) {
	# Read module's lang files
	local $mdir = "$root/$_[0]";
	foreach $o (@lang_order_list) {
		&read_file_cached("$mdir/$dir/$o", \%text);
		}
	if ($ol) {
		foreach $o (@lang_order_list) {
			&read_file_cached("$mdir/$ol/$o", \%text);
			}
		}
	&read_file_cached("$usermin::config{'usermin_dir'}/$_[0]/custom-lang", \%text);
	}
foreach $k (keys %text) {
	$text{$k} =~ s/\$(\{([^\}]+)\}|([A-Za-z0-9\.\-\_]+))/text_subs($2 || $3,\%text)/ge;
	}
return %text;

}

1;

