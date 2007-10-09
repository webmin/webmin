# spam-lib.pl
# Common functions for parsing and editing the spamassassin config file

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';

$local_cf = $config{'local_cf'};
$warn_procmail = $config{'warn_procmail'};
if ($module_info{'usermin'}) {
	# Running under Usermin, editing user's personal config file
	&switch_to_remote_user();
	&create_user_config_dirs();
	if ($local_cf !~ /^\//) {
		$local_cf = "$remote_user_info[7]/$local_cf";
		if ($local_cf =~ /^(.*)\// && !-d $1) {
			mkdir($1, 0700);
			}
		}
	$database_userpref_name = $remote_user;
	$database_userpref_name = "fotego";	# XXX remove!
	$include_config_files = $config{'readfiles'};
	$add_to_db = 1;
	}
else {
	# Running under Webmin, typically editing global config file
	%access = &get_module_acl();
	if ($access{'file'}) {
		$local_cf = $access{'file'};
		}
	if ($access{'nocheck'}) {
		$warn_procmail = 0;
		}
	$database_userpref_name = $config{'dbglobal'} || '@GLOBAL';
	$include_config_files = 1;
	$add_to_db = $config{'addto'};
	}
$ldap_spamassassin_attr = $config{'attr'} || 'spamassassin';
$ldap_username_attr = $config{'uid'} || 'uid';
$add_cf = !-d $local_cf ? $local_cf :
	  $module_info{'usermin'} ? "$local_cf/user_prefs" :
				    "$local_cf/local.cf";

# get_config([file], [for-global])
# Return a structure containing the contents of the spamassassin config file
sub get_config
{
local $forglobal = $_[1];
local @rv;
if ($include_config_files || $forglobal) {
	# Reading from file(s)
	local $lnum = 0;
	local $file = $_[0] || $local_cf;
	if (-d $file) {
		# A directory of files - read them all
		opendir(DIR, $file);
		local @files = sort { $a cmp $b } readdir(DIR);
		closedir(DIR);
		local $f;
		foreach $f (@files) {
			if ($f =~ /\.cf$/) {
				local $add = &get_config("$file/$f");
				map { $_->{'index'} += scalar(@rv) } @$add;
				push(@rv, @$add);
				}
			}
		}
	else {
		# A single file that can be read right here
		open(FILE, $file);
		while(<FILE>) {
			s/\r|\n//g;
			s/^#.*$//;
			if (/^(\S+)\s*(.*)$/) {
				local $dir = { 'name' => $1,
					       'value' => $2,
					       'index' => scalar(@rv),
					       'file' => $file,
					       'mode' => 0,
					       'line' => $lnum };
				$dir->{'words'} =
					[ split(/\s+/, $dir->{'value'}) ];
				push(@rv, $dir);
				}
			$lnum++;
			}
		close(FILE);
		}
	}

if ($config{'mode'} == 1 || $config{'mode'} == 2) {
	# Add from SQL database
	local $dbh = &connect_spamassasin_db();
	&error($dbh) if (!ref($dbh));
	local $cmd = $dbh->prepare("select preference,value from userpref where username = ?");
	$cmd->execute(!$forglobal ? $database_userpref_name :
		      $config{'dbglobal'} ? $config{'dbglobal'} : '@GLOBAL');
	while(my ($name, $value) = $cmd->fetchrow()) {
		local $dir = { 'name' => $name,
			       'value' => $value,
			       'index' => scalar(@rv),
			       'mode' => $config{'mode'} };
		$dir->{'words'} =
			[ split(/\s+/, $dir->{'value'}) ];
		push(@rv, $dir);
		}
	$cmd->finish();
	}
elsif ($config{'mode'} == 3 && !$forglobal) {
	# From LDAP
	local $ldap = &connect_spamassassin_ldap();
	&error($ldap) if (!ref($ldap));
	local $uinfo = &get_ldap_user($ldap);
	if ($uinfo) {
		foreach my $a ($uinfo->get_value($ldap_spamassassin_attr)) {
			local ($name, $value) = split(/\s+/, $a, 2);
			local $dir = { 'name' => $name,
				       'value' => $value,
				       'index' => scalar(@rv),
				       'oldattr' => $a,
				       'mode' => $config{'mode'} };
			$dir->{'words'} =
				[ split(/\s+/, $dir->{'value'}) ];
			push(@rv, $dir);
			}
		}
	}

return \@rv;
}

# find(name, &config)
sub find
{
local @rv;
foreach $c (@{$_[1]}) {
	push(@rv, $c) if (lc($c->{'name'}) eq lc($_[0]));
	}
return wantarray ? @rv : $rv[0];
}

# find_value(name, &config)
sub find_value
{
local @rv = map { $_->{'value'} } &find(@_);
return wantarray ? @rv : $rv[0];
}

# save_directives(&config, name|&old, &new, valuesonly)
# Update the config file with some directives
sub save_directives
{
if ($module_info{'usermin'} && $local_cf =~ /^(.*)\/([^\/]+)$/) {
	# Under Usermin, make sure .spamassassin exists
	local $spamdir = $1;
	if (!-d $spamdir) {
		&make_dir($spamdir, 0755);
		}
	}
local @old = ref($_[1]) ? @{$_[1]} : &find($_[1], $_[0]);
local @new = $_[3] ? &make_directives($_[1], $_[2]) : @{$_[2]};
local $i;
for($i=0; $i<@old || $i<@new; $i++) {
	local $line;
	if ($new[$i]) {
		$line = $new[$i]->{'name'};
		$line .= " ".$new[$i]->{'value'} if ($new[$i]->{'value'} ne '');
		}
	if ($old[$i] && $new[$i]) {
		# Replacing a directive
		if ($old[$i]->{'name'} eq $new[$i]->{'name'} &&
		    $old[$i]->{'value'} eq $new[$i]->{'value'}) {
			# Nothing to do!
			next;
			}
		if ($old[$i]->{'mode'} == 0) {
			# In a file
			local $lref = &read_file_lines($old[$i]->{'file'});
			$lref->[$old[$i]->{'line'}] = $line;
			}
		elsif ($old[$i]->{'mode'} == 1 || $old[$i]->{'mode'} == 2) {
			# In an SQL DB
			local $dbh = &connect_spamassasin_db();
			&error($dbh) if (!ref($dbh));
			local $cmd = $dbh->prepare("update userpref set value = ? where username = ? and preference = ? and value = ?");
			$cmd->execute($new[$i]->{'value'},
				      $database_userpref_name,
				      $old[$i]->{'name'},
				      $old[$i]->{'value'});
			$cmd->finish();
			}
		elsif ($old[$i]->{'mode'} == 3) {
			# In LDAP - modify the attribute
			print STDERR "changing $old[$i]->{'value'} to $new[$i]->{'value'}\n";
			local $ldap = &connect_spamassassin_ldap();
			&error($ldap) if (!ref($ldap));
			local $uinfo = &get_ldap_user($ldap);
			$uinfo || &error(&text('ldap_euser',
					       $database_userpref_name));
			local @values = $uinfo->get_value(
						$ldap_spamassassin_attr);
			print STDERR "modify old values = ",join(" ", @values),"\n";
			@values = grep { $_ ne $new[$i]->{'name'}." ".
					       $new[$i]->{'value'} } @values;
			foreach my $v (@values) {
				if ($v eq $old[$i]->{'name'}." ".
                                          $old[$i]->{'value'}) {
					$v = $new[$i]->{'name'}." ".
                                             $new[$i]->{'value'};
					}
				}
			print STDERR "modify new values = ",join(" ", @values),"\n";
			local $rv = $ldap->modify(
			    $uinfo->dn(),
			    replace => { $ldap_spamassassin_attr =>
					 \@values });
			if (!$rv || $rv->code) {
				&error(&text('eldap',
				    $rv ? $rv->error : "Unknown modify error"));
				}
			}
		$_[0]->[$old[$i]->{'index'}] = $new[$i];
		}
	elsif ($old[$i]) {
		# Deleting a directive
		if ($old[$i]->{'mode'} == 0) {
			# From a file
			local $lref = &read_file_lines($old[$i]->{'file'});
			splice(@$lref, $old[$i]->{'line'}, 1);
			foreach $c (@{$_[0]}) {
				if ($c->{'line'} > $old[$i]->{'line'} &&
				    $c->{'file'} eq $old[$i]->{'file'}) {
					$c->{'line'}--;
					}
				}
			}
		elsif ($old[$i]->{'mode'} == 1 || $old[$i]->{'mode'} == 2) {
			# From an SQL DB
			local $dbh = &connect_spamassasin_db();
			&error($dbh) if (!ref($dbh));
			local $cmd = $dbh->prepare("delete from userpref where username = ? and preference = ? and value = ?");
			$cmd->execute($database_userpref_name,
				      $old[$i]->{'name'},
				      $old[$i]->{'value'});
			$cmd->finish();
			}
		elsif ($old[$i]->{'mode'} == 3) {
			# From LDAP .. get current values, and remove this one
			# XXX not working when doing a list, ie.
			# XXX jcameron, fcchan, lara -> jcameron, lara
			# XXX removes lara !
			print STDERR "removing $old[$i]->{'name'} with $old[$i]->{'value'}\n";
			local $ldap = &connect_spamassassin_ldap();
			&error($ldap) if (!ref($ldap));
			local $uinfo = &get_ldap_user($ldap);
			$uinfo || &error(&text('ldap_euser',
					       $database_userpref_name));
			local @values = $uinfo->get_value(
						$ldap_spamassassin_attr);
			print STDERR "delete old values = ",join(" ", @values),"\n";
			@values = grep { $_ ne $old[$i]->{'name'}." ".
					       $old[$i]->{'value'} } @values;
			print STDERR "delete new values = ",join(" ", @values),"\n";
			local $rv = $ldap->modify(
			    $uinfo->dn(),
			    replace => { $ldap_spamassassin_attr =>
					 \@values });
			if (!$rv || $rv->code) {
				&error(&text('eldap',
				    $rv ? $rv->error : "Unknown delete error"));
				}
			}

		# Fix up indexes
		splice(@{$_[0]}, $old[$i]->{'index'}, 1);
		foreach $c (@{$_[0]}) {
			if ($c->{'index'} > $old[$i]->{'index'}) {
				$c->{'index'}--;
				}
			}
		}
	elsif ($new[$i]) {
		# Adding a directive
		local $addmode = scalar(@old) ? $old[0]->{'mode'} :
				 $new[$i]->{'name'} =~ /^user_scores_/ ? 0 :
				 $add_to_db ? $config{'mode'} : 0;
		if ($addmode == 0) {
			# To a file
			local $lref = &read_file_lines($add_cf);
			$new[$i]->{'line'} = @$lref;
			push(@$lref, $line);
			}
		elsif ($addmode == 1 || $addmode == 2) {
			# To an SQL DB
			local $dbh = &connect_spamassasin_db();
			&error($dbh) if (!ref($dbh));
			local $cmd = $dbh->prepare("insert into userpref (username, preference, value) values (?, ?, ?)");
			$cmd->execute($database_userpref_name,
				      $new[$i]->{'name'},
				      $new[$i]->{'value'});
			$cmd->finish();
			}
		elsif ($addmode == 3) {
			# To LDAP
			local $ldap = &connect_spamassassin_ldap();
			&error($ldap) if (!ref($ldap));
			local $uinfo = &get_ldap_user($ldap);
			$uinfo || &error(&text('ldap_euser',
					       $database_userpref_name));
			local $rv = $ldap->modify(
			    $uinfo->dn(),
			    add => { $ldap_spamassassin_attr =>
				$new[$i]->{'name'}." ".$new[$i]->{'value'} });
			if (!$rv || $rv->code) {
				&error(&text('eldap',
				     $rv ? $rv->error : "Unknown add error"));
				}
			}
		$new[$i]->{'mode'} = $addmode;
		$new[$i]->{'index'} = @{$_[0]};
		push(@{$_[0]}, $new[$i]);
		}
	}
}

# make_directives(name, &values)
sub make_directives
{
return map { { 'name' => $_[0],
	       'value' => $_ } } @{$_[1]};
}

### UI functions ###

# edit_table(name, &headings, &&values, &sizes, [&convfunc], blankrows)
# Display a table of values for editing, with one blank row
sub edit_table
{
local ($h, $v);
print "<table border>\n";
print "<tr $tb>\n";
foreach $h (@{$_[1]}) {
	print "<td><b>$h</b></td>\n";
	}
print "</tr>\n";
local $i = 0;
local $cfunc = $_[4] || \&default_convfunc;
local $blanks = $_[5] || 1;
foreach $v (@{$_[2]}, map { [ ] } (1 .. $blanks)) {
	print "<tr $cb>\n";
	for($j=0; $j<@{$_[1]}; $j++) {
		print "<td>",&$cfunc($j, "$_[0]_${i}_${j}", $_[3]->[$j],
				     $v->[$j], $v),"</td>";
		}
	print "</tr>\n";
	$i++;
	}
print "</table>\n";
}

# default_convfunc(column, name, size, value)
sub default_convfunc
{
return "<input name=$_[1] size=$_[2] value='".&html_escape($_[3])."'>";
}

# parse_table(name, &parser)
# Parse the inputs from a table and return an array of results
sub parse_table
{
local ($i, @rv);
local $pfunc = $_[1] || \&default_parsefunc;
for($i=0; defined($in{"$_[0]_${i}_0"}); $i++) {
	local ($j, $v, @vals);
	for($j=0; defined($v = $in{"$_[0]_${i}_${j}"}); $j++) {
		push(@vals, $v);
		}
	local $p = &$pfunc("$_[0]_${i}", @vals);
	push(@rv, $p) if (defined($p));
	}
return @rv;
}

# default_parsefunc(rowname, value, ...)
# Returns a value or undef if empty, or calls &error if invalid
sub default_parsefunc
{
return $_[1] ? join(" ", @_[1..$#_]) : undef;
}

# start_form(cgi, header)
sub start_form
{
print "<form action=$_[0] method=post>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$_[1]</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";
}

# end_form(buttonname, buttonvalue, ...)
sub end_form
{
print "</table></td></tr></table>\n";
if (@_) {
	local $p = int(200 / scalar(@_));
	print "<table width=100%><tr>\n";
	local $i;
	for($i=0; $i<@_; $i+=2 ) {
		local $al = $i == 0 ? "align=left" :
			    $i == @_-2 ? "align=right" : "align=center";
		local $n = $_[$i] ? "name='$_[$i]'" : "";
		local $v = &html_escape($_[$i+1]);
		print "<td width=$p% $al><input type=submit $n value='$v'></td>\n";
		}
	print "</table>\n";
	}
print "</form>\n";
}

# yes_no_field(name, value, default)
sub yes_no_field
{
local $v = !$_[1] ? -1 : $_[1]->{'value'};
local $def = &find_default($_[0], $_[2]) ? $text{'yes'} : $text{'no'};
printf "<input type=radio name=$_[0] value=1 %s> %s\n",
	$v == 1 ? "checked" : "", $text{'yes'};
printf "<input type=radio name=$_[0] value=0 %s> %s\n",
	$v == 0 ? "checked" : "", $text{'no'};
printf "<input type=radio name=$_[0] value=-1 %s> %s (%s)\n",
	$v == -1 ? "checked" : "", $text{'default'}, $def;
}

# parse_yes_no(&config, name)
sub parse_yes_no
{
&save_directives($_[0], $_[1], $in{$_[1]} == 1 ? [ 1 ] :
			       $in{$_[1]} == 0 ? [ 0 ] : [ ], 1);
}

# option_field(name, value, default, &opts)
sub option_field
{
local $v = !$_[1] ? -1 : $_[1]->{'value'};
local $def = &find_default($_[0], $_[2]);
local ($defopt) = grep { $_->[0] eq $def } @{$_[3]};
print &ui_radio($_[0], $v,
		[ @{$_[3]}, [ -1, "$text{'default'} ($defopt->[1])" ] ]);
}

sub parse_option
{
&save_directives($_[0], $_[1], $in{$_[1]} == -1 ? [ ] : [ $in{$_[1]} ], 1);
}

# opt_field(name, value, size, default)
sub opt_field
{
local $def = &find_default($_[0], $_[3]) if ($_[3]);
printf "<input type=radio name=$_[0]_def value=1 %s> %s %s\n",
	$_[1] ? "" : "checked", $text{'default'}, $_[3] ? " ($def)" : "";
printf "<input type=radio name=$_[0]_def value=0 %s>\n",
	$_[1] ? "checked" : "";
printf "<input name=$_[0] size=$_[2] value='%s'>\n",
	$_[1] ? &html_escape(ref($_[1]) ? $_[1]->{'value'} : $_[1]) : "";
}

# parse_opt(&config, name, [&checkfunc])
sub parse_opt
{
if (defined($in{"$_[1]_default"}) && $in{"$_[1]_default"} eq $in{$_[1]} ||
    !defined($in{"$_[1]_default"}) && $in{"$_[1]_def"}) {
	&save_directives($_[0], $_[1], [ ], 1);
	}
else {
	&{$_[2]}($in{$_[1]}) if ($_[2]);
	&save_directives($_[0], $_[1], [ $in{$_[1]} ], 1);
	}
}

# edit_textbox(name, &values, width, height)
sub edit_textbox
{
print "<textarea name=$_[0] cols=$_[2] rows=$_[3]>";
foreach $v (@{$_[1]}) {
	print "$v\n";
	}
print "</textarea>\n";
}

# parse_textbox(&config, name)
sub parse_textbox
{
$in{$_[1]} =~ s/^\s+//;
$in{$_[1]} =~ s/\s+$//;
local @v = split(/\s+/, $in{$_[1]});
&save_directives($_[0], $_[1], \@v, 1);
}

# get_procmailrc()
# Returns the full paths to the procmail config files in use, the last one
# being the user's config
sub get_procmailrc
{
if ($module_info{'usermin'}) {
	local @rv;
	push(@rv, $config{'global_procmailrc'});
	push(@rv, $config{'procmailrc'} || $procmail::procmailrc);
	return @rv;
	}
else {
	return ( $access{'procmailrc'} || $config{'procmailrc'} || $procmail::procmailrc );
	}
}

# find_default(name, compiled-in-default)
sub find_default
{
if ($config{'global_cf'}) {
	if (!defined($global_config_cache)) {
		$global_config_cache = &get_config($config{'global_cf'}, 1);
		}
	local $v = &find_value($_[0], $global_config_cache);
	return $v if (defined($v));
	}
return $_[1];
}

# can_use_page(page)
# Returns 1 if some page can be used, 0 if not
sub can_use_page
{
local %avail_icons;
if ($module_info{'usermin'}) {
	%avail_icons = map { $_, 1 } split(/,/, $config{'avail_icons'});
	}
else {
	%avail_icons = map { $_, 1 } split(/,/, $access{'avail'});
	}
local $p = $_[0] eq "simple" ? "header" : $_[0];
return $avail_icons{$p};
}

# can_use_check(page)
# Calls error if some page cannot be used
sub can_use_check
{
&can_use_page($_[0]) || &error($text{'ecannot'});
}

# get_spamassassin_version(&out)
sub get_spamassassin_version
{
local $out;
&execute_command("$config{'spamassassin'} -V", undef, \$out, \$out, 0, 1);
${$_[0]} = $out if ($_[0]);
return $out =~ /(version|Version:)\s+(\S+)/ ? $2 : undef;
}

# version_atleast(num)
sub version_atleast
{
if (!$version_cache) {
	$version_cache = &get_spamassassin_version();
	}
return $version_cache >= $_[0];
}

# spam_file_folder()
sub spam_file_folder
{
&foreign_require("mailbox", "mailbox-lib.pl");
local ($sf) = grep { $_->{'spam'} } &mailbox::list_folders();
return $sf;
}

# disable_indexing(&folder)
sub disable_indexing
{
if (!$config{'index_spam'}) {
	$mailbox::config{'index_min'} = 1000000000;
	unlink(&mailbox::user_index_file($_[0]->{'file'}));
	}
}

# get_process_pids()
# Returns the PIDs and names of SpamAssassin daemon processes like spamd
sub get_process_pids
{
local ($pn, @pids);
foreach $pn (split(/\s+/, $config{'processes'})) {
	push(@pids, map { [ $_, $pn ] } &find_byname($pn));
	}
return @pids;
}

sub lock_spam_files
{
local $conf = &get_config();
@spam_files = &unique(map { $_->{'file'} } @$conf);
local $f;
foreach $f (@spam_files) {
	&lock_file($f);
	}
}

sub unlock_spam_files
{
local $f;
foreach $f (@spam_files) {
	&unlock_file($f);
	}
}

# show_buttons(number)
sub show_buttons
{
print "<table width=100%> <tr>\n";
local $onclick = "onClick='return check_clicks(form)'"
	if (defined(&check_clicks_function));
print "<td align=left><input type=submit name=inbox value=\"$text{'mail_inbox'}\" $onclick></td>\n";
print "<td align=left><input type=submit name=whitelist value=\"$text{'mail_whitelist2'}\" $onclick></td>\n";
if (&has_command($config{'sa_learn'})) {
	print "<td align=center><input type=submit name=ham value=\"$text{'mail_ham'}\" $onclick></td>\n";
	}
print "<td align=right><input type=submit name=delete value=\"$text{'mail_delete'}\" $onclick></td>\n";
print "<td align=right><input type=submit name=razor value=\"$text{'mail_razor'}\" $onclick></td>\n";
print "</tr></table>\n";
}

# restart_spamd()
# Re-start all SpamAssassin processes, or return an error message
sub restart_spamd
{
if ($config{'restart_cmd'}) {
	local $out = &backquote_logged(
		"$config{'restart_cmd'} 2>&1 </dev/null");
	if ($? || $out =~ /error|failed/i) {
		return "<pre>$out</pre>";
		}
	}
else {
	local @pids = &get_process_pids();
	@pids || return $text{'apply_none'};
	local $p;
	foreach $p (@pids) {
		&kill_logged("HUP", $p->[0]);
		}
	}
return undef;
}

# find_spam_recipe(&recipes)
# Returns the recipe that runs spamassassin
sub find_spam_recipe
{
local $r;
foreach $r (@{$_[0]}) {
	if ($r->{'action'} =~ /spamassassin/i ||
	    $r->{'action'} =~ /spamc/i) {
		return $r;
		}
	}
return undef;
}

# find_file_recipe(&recipes)
# Returns the recipe for delivering mail based on the X-Spam-Status header
sub find_file_recipe
{
local ($r, $c);
foreach $r (@{$_[0]}) {
	foreach $c (@{$r->{'conds'}}) {
		if ($c->[1] =~ /X-Spam-Status/i) {
			return $r;
			}
		}
	}
return undef;
}

# find_virtualmin_recipe(&recipes)
# Returns the recipe that runs the Virtualmin lookup command
sub find_virtualmin_recipe
{
local ($r, $c);
foreach $r (@{$_[0]}) {
	if ($r->{'action'} =~ /^VIRTUALMIN=/) {
		return $r;
		}
	}
return undef;
}

# find_force_default_receipe(&recipes)
# Returns the recipe that forces delivery to $DEFAULT, used by Virtualmin and
# others to prevent per-user .procmailrc settings
sub find_force_default_receipe
{
local ($r, $c);
foreach $r (@{$_[0]}) {
	if ($r->{'action'} eq '$DEFAULT' && !@{$r->{'conds'}}) {
		return $r;
		}
	}
return undef;
}

# get_simple_tests(&conf)
sub get_simple_tests
{
local ($conf) = @_;
local (@simple, %simple);
foreach my $h (&find("header", $conf)) {
	if ($h->{'value'} =~ /^(\S+)\s+(\S+)\s+=~\s+\/(.*)\/(\S*)\s*$/) {
		push(@simples, { 'header_dir' => $h,
				 'name' => $1,
				 'header' => lc($2),
			 	 'regexp' => $3,
				 'flags' => $4, });
		$simples{$1} = $simples[$#simples];
		}
	}
foreach my $b (&find("body", $conf), &find("full", $conf),
	       &find("uri", $conf)) {
	if ($b->{'value'} =~ /^(\S+)\s+\/(.*)\/(\S*)\s*$/) {
		push(@simples, { $b->{'name'}.'_dir' => $b,
				 'name' => $1,
				 'header' => $b->{'name'},
			 	 'regexp' => $2,
				 'flags' => $3, });
		$simples{$1} = $simples[$#simples];
		}
	}
foreach my $s (&find("score", $conf)) {
	if ($s->{'value'} =~ /^(\S+)\s+(\S+)/ && $simples{$1}) {
		$simples{$1}->{'score_dir'} = $s;
		$simples{$1}->{'score'} = $2;
		}
	}
foreach my $d (&find("describe", $conf)) {
	if ($d->{'value'} =~ /^(\S+)\s+(\S.*)/ && $simples{$1}) {
		$simples{$1}->{'describe_dir'} = $d;
		$simples{$1}->{'describe'} = $2;
		}
	}
return @simples;
}

# get_procmail_command()
# Returns the command that should be used in /etc/procmailrc to call
# spamassassin, such as spamc or the full spamassassin path
sub get_procmail_command
{
if ($config{'procmail_cmd'} eq '*') {
	# Is spamd running?
	if (&get_process_pids()) {
		local $spamc = &has_command("spamc");
		return $spamc if ($spamc);
		}
	return &has_command($config{'spamassassin'});
	}
elsif ($config{'procmail_cmd'}) {
	return $config{'procmail_cmd'};
	}
else {
	return &has_command($config{'spamassassin'});
	}
}

# execute_before(section)
# If a before-change command is configured, run it. If it fails, call error
sub execute_before
{
local ($section) = @_;
if ($config{'before_cmd'}) {
	$ENV{'SPAM_SECTION'} = $section;
	local $out;
	local $rv = &execute_command(
			$config{'before_cmd'}, undef, \$out, \$out);
	$rv && &error(&text('before_ecmd',
			    "<pre>".&html_escape($out)."</pre>"));
	}
}

# execute_after(section)
# If a after-change command is configured, run it. If it fails, call error
sub execute_after
{
local ($section) = @_;
if ($config{'after_cmd'}) {
	$ENV{'SPAM_SECTION'} = $section;
	local $out;
	local $rv = &execute_command(
			$config{'after_cmd'}, undef, \$out, \$out);
	$rv && &error(&text('after_ecmd',
			    "<pre>".&html_escape($out)."</pre>"));
	}
}

# check_spamassassin_db()
# Checks if the LDAP or MySQL backend can be contacted, and if not returns
# an error message.
sub check_spamassassin_db
{
if ($config{'mode'} == 0) {
	return undef;	# Local files always work
	}
elsif ($config{'mode'} == 1 || $config{'mode'} == 2) {
	# Connect to a database
	local $dbh = &connect_spamassasin_db();
	return $dbh if (!ref($dbh));
	local $testcmd = $dbh->prepare("select * from userpref limit 1");
	if (!$testcmd || !$testcmd->execute()) {
		undef($connect_spamassasin_db_cache);
		$dbh->disconnect();
		return &text('connect_equery', "<tt>$config{'db'}</tt>",
					       "<tt>userpref</tt>");
		}
	$testcmd->finish();
	undef($connect_spamassasin_db_cache);
	$dbh->disconnect();
	return undef;
	}
elsif ($config{'mode'} == 3) {
	# Connect to LDAP
	local $ldap = &connect_spamassassin_ldap();
	return $ldap if (!ref($ldap));
	local $rv = $ldap->search(base => $config{'base'},
				  filter => "(uid=$remote_user)",
				  sizelimit => 1);
	if (!$rv || $rv->code) {
		return &text('connect_ebase', "<tt>$config{'base'}</tt>",
			     $rv ? $rv->error : "Unknown search error");
		}
	return undef;
	}
else {
	return "Unknown config mode $config{'mode'} !";
	}
}

# connect_spamassasin_db()
# Attempts to connect to the SpamAssasin MySQL or PostgreSQL database. Returns
# a driver handle on success, or an error message string on failure.
sub connect_spamassasin_db
{
if (defined($connect_spamassasin_db_cache)) {
	return $connect_spamassasin_db_cache;
	}
local $driver = $config{'mode'} == 1 ? "mysql" : "Pg";
local $drh;
eval <<EOF;
use DBI;
\$drh = DBI->install_driver(\$driver);
EOF
if ($@) {
	return &text('connect_edriver', "<tt>DBD::$driver</tt>");
        }
local $dbistr = &make_dbistr($driver, $config{'db'}, $config{'server'});
local $dbh = $drh->connect($dbistr,
                           $config{'user'}, $config{'pass'}, { });
$dbh || return &text('connect_elogin',
		     "<tt>$config{'db'}</tt>", $drh->errstr)."\n";
$connect_spamassasin_db_cache = $dbh;
return $dbh;
}

# connect_spamassassin_ldap()
# Attempts to connect to the configured LDAP DB, and returns the handle on
# success, or an error message on failure.
sub connect_spamassassin_ldap
{
if (defined($connect_spamassasin_ldap_cache)) {
	return $connect_spamassasin_ldap_cache;
	}
eval "use Net::LDAP";
if ($@) {
	return &text('connect_eldapmod', "<tt>Net::LDAP</tt>");
	}
local $port = $config{'port'} || 389;
local $ldap = Net::LDAP->new($config{'server'}, port => $port);
if (!$ldap) {
	return &text('connect_eldap', "<tt>$config{'server'}</tt>", $port);
	}
local $mesg = $ldap->bind(dn => $config{'user'}, password => $config{'pass'});
if (!$mesg || $mesg->code) {
	return &text('connect_eldaplogin', "<tt>$config{'server'}</tt>",
		     "<tt>$config{'user'}</tt>",
		     $mesg ? $mesg->error : "Unknown error");
	}
$connect_spamassasin_ldap_cache = $ldap;
return $ldap;
}

sub make_dbistr
{
local ($driver, $db, $host) = @_;
local $rv;
if ($driver eq "mysql") {
	$rv = "database=$db";
	}
elsif ($driver eq "Pg") {
	$rv = "dbname=$db";
	}
else {
	$rv = $db;
	}
if ($host) {
	$rv .= ";host=$host";
	}
return $rv;
}

# get_ldap_user(&ldap, [username])
# Returns the LDAP object for a user, or undef if not found
sub get_ldap_user
{
local ($ldap, $user) = @_;
$user ||= $database_userpref_name;
#if (exists($get_ldap_user_cache{$user})) {
#	return $get_ldap_user_cache{$user};
#	}
local $rv = $ldap->search(base => $config{'base'},
			  filter => "($ldap_username_attr=$user)",
			 );
if (!$rv || $rv->code) {
	&error(&text('eldap', $rv ? $rv->error : "Search failed"));
	}
local ($uinfo) = $rv->all_entries;
$get_ldap_user_cache{$user} = $uinfo;
return $uinfo;
}

1;

