# fetchmail-lib.pl
# Functions for parsing fetchmail config files

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();

if ($module_info{'usermin'}) {
	if ($no_switch_user) {
		@remote_user_info = getpwnam($remote_user);
		}
	else {
		&switch_to_remote_user();
		&create_user_config_dirs();
		}
	$cron_cmd = "$user_module_config_directory/check.pl";
	$cron_user = $remote_user;
	$fetchmail_config = "$remote_user_info[7]/.fetchmailrc";
	$can_cron = $config{'can_cron'};
	$can_daemon = $config{'can_daemon'};
	}
else {
	$cron_cmd = "$module_config_directory/check.pl";
	$cron_user = "root";
	$fetchmail_config = $config{'config_file'};
	$can_cron = $access{'cron'};
	$can_daemon = $access{'daemon'};
	}

# parse_config_file(file, [&global])
# Parses a fetchmail config file into a list of hashes, each representing
# one mail server to poll
sub parse_config_file
{
local $lnum = 0;
local ($line, @rv, @toks);

# Tokenize the file
open(FILE, $_[0]);
while($line = <FILE>) {
	$line =~ s/\r|\n//g;
	$line =~ s/^\s*#.*$//;
	while($line =~ /^[\s:;,]*"([^"]*)"(.*)$/ ||
	      $line =~ /^[\s:;,]*'([^"]*)'(.*)$/ ||
	      $line =~ /^[\s:;,]*([^\s:;,]+)(.*)$/) {
		push(@toks, [ $1, $lnum ]);
		$line = $2;
		}
	$lnum++;
	}
close(FILE);

# Split into poll sections
@toks = grep { $_->[0] !~ /^(and|with|has|wants|options|here)$/i } @toks;
local ($poll, $user, $i);
for($i=0; $i<@toks; $i++) {
	local $t = $toks[$i];

	# Server options
	if ($t->[0] eq 'poll' || $t->[0] eq 'server' ||
	    $t->[0] eq 'skip' || $t->[0] eq 'defaults') {
		# Start of a new poll
		$poll = { 'line' => $t->[1],
			  'file' => $_[0],
			  'index' => scalar(@rv),
			  'skip' => ($t->[0] eq 'skip'),
			  'defaults' => ($t->[0] eq 'defaults') };
		$poll->{'poll'} = $toks[++$i]->[0] if (!$poll->{'defaults'});
		undef($user);
		push(@rv, $poll);
		}
	elsif ($t->[0] eq 'proto' || $t->[0] eq 'protocol') {
		$poll->{'proto'} = $toks[++$i]->[0];
		}
	elsif ($t->[0] eq 'via') {
		$poll->{'via'} = $toks[++$i]->[0];
		}
	elsif ($t->[0] eq 'port') {
		$poll->{'port'} = $toks[++$i]->[0];
		}
	elsif ($t->[0] eq 'timeout') {
		$poll->{'timeout'} = $toks[++$i]->[0];
		}
	elsif ($t->[0] eq 'interface') {
		$poll->{'interface'} = $toks[++$i]->[0];
		}
	elsif ($t->[0] eq 'monitor') {
		$poll->{'monitor'} = $toks[++$i]->[0];
		}
	elsif ($t->[0] eq 'auth' || $t->[0] eq 'authenticate') {
		$poll->{'auth'} = $toks[++$i]->[0];
		}

	# User options
	elsif ($t->[0] eq 'user' || $t->[0] eq 'username') {
		$user = { 'user' => $toks[++$i]->[0] };
		push(@{$poll->{'users'}}, $user);
		}
	elsif ($t->[0] eq 'pass' || $t->[0] eq 'password') {
		$user->{'pass'} = $toks[++$i]->[0];
		}
	elsif ($t->[0] eq 'is' || $t->[0] eq 'to') {
		$i++;
		while($i < @toks &&
		      $toks[$i]->[1] == $t->[1]) {
			push(@{$user->{'is'}}, $toks[$i]->[0]);
			$i++;
			}
		$i--;
		}
	elsif ($t->[0] eq 'folder') {
		$user->{'folder'} = $toks[++$i]->[0];
		}
	elsif ($t->[0] eq 'keep') { $user->{'keep'} = 1; }
	elsif ($t->[0] eq 'nokeep') { $user->{'keep'} = 0; }
	elsif ($t->[0] eq 'no' && $toks[$i+1]->[0] eq 'keep') {
		$user->{'keep'} = 0;
		$i++;
		}
	elsif ($t->[0] eq 'fetchall') { $user->{'fetchall'} = 1; }
	elsif ($t->[0] eq 'nofetchall') { $user->{'fetchall'} = 0; }
	elsif ($t->[0] eq 'no' && $toks[$i+1]->[0] eq 'fetchall') {
		$user->{'fetchall'} = 0;
		$i++;
		}
	elsif ($t->[0] eq 'ssl') { $user->{'ssl'} = 1; }
	elsif ($t->[0] eq 'nossl') { $user->{'ssl'} = 0; }
	elsif ($t->[0] eq 'no' && $toks[$i+1]->[0] eq 'ssl') {
		$user->{'ssl'} = 0;
		$i++;
		}
	elsif ($t->[0] eq 'preconnect') {
		$user->{'preconnect'} = $toks[++$i]->[0];
		}
	elsif ($t->[0] eq 'postconnect') {
		$user->{'postconnect'} = $toks[++$i]->[0];
		}

	else {
		# Found an unknown option!
		if ($user) {
			push(@{$user->{'unknown'}}, $t->[0]);
			}
		elsif ($poll) {
			push(@{$poll->{'unknown'}}, $t->[0]);
			}
		}

	if ($poll) {
		if ($i<@toks) {
			$poll->{'eline'} = $toks[$i]->[1];
			}
		else {
			$poll->{'eline'} = $toks[$#toks]->[1];
			}
		}
	}

return @rv;
}

# create_poll(&poll, file)
# Add a new poll section to a fetchmail config file
sub create_poll
{
local $lref = &read_file_lines($_[1]);
if ($_[0]->{'defaults'}) {
	# Put a new defaults section at the top
	splice(@$lref, 0, 0, &poll_lines($_[0]));
	}
else {
	push(@$lref, &poll_lines($_[0]));
	}
&flush_file_lines();
}

# delete_poll(&poll, file)
# Delete a poll section from a fetchmail config file
sub delete_poll
{
local $lref = &read_file_lines($_[1]);
splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1);
&flush_file_lines();
}

# modify_poll(&poll, file)
# Modify a poll section in a fetchmail config file
sub modify_poll
{
local $lref = &read_file_lines($_[1]);
splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1,
       &poll_lines($_[0]));
&flush_file_lines();
}

sub poll_lines
{
local @rv;
local $name = $_[0]->{'poll'};
$name = "\"$name\"" if ($name =~ /[\s:;,]/);
if ($_[0]->{'skip'}) {
	push(@rv, "skip $name");
	}
elsif ($_[0]->{'defaults'}) {
	push(@rv, "defaults $name");
	}
else {
	push(@rv, "poll $name");
	}
push(@rv, "\tproto $_[0]->{'proto'}") if ($_[0]->{'proto'});
push(@rv, "\tauth $_[0]->{'auth'}") if ($_[0]->{'auth'});
push(@rv, "\tvia $_[0]->{'via'}") if ($_[0]->{'via'});
push(@rv, "\tport $_[0]->{'port'}") if ($_[0]->{'port'});
push(@rv, "\ttimeout $_[0]->{'timeout'}") if ($_[0]->{'timeout'});
push(@rv, "\tinterface \"$_[0]->{'interface'}\"") if ($_[0]->{'interface'});
push(@rv, "\tmonitor $_[0]->{'monitor'}") if ($_[0]->{'monitor'});
push(@rv, "\t".join(" ", map { /^\S+$/ ? $_ : "\"$_\"" }
			     @{$_[0]->{'unknown'}})) if (@{$_[0]->{'unknown'}});

foreach $u (@{$_[0]->{'users'}}) {
	push(@rv, "\tuser \"$u->{'user'}\"");
	push(@rv, "\tpass \"$u->{'pass'}\"") if ($u->{'pass'});
	push(@rv, "\tis ".join(" ", @{$u->{'is'}})) if (@{$u->{'is'}});
	push(@rv, "\tfolder $u->{'folder'}") if ($u->{'folder'});
	push(@rv, "\tkeep") if ($u->{'keep'} eq '1');
	push(@rv, "\tnokeep") if ($u->{'keep'} eq '0');
	push(@rv, "\tfetchall") if ($u->{'fetchall'} eq '1');
	push(@rv, "\tno fetchall") if ($u->{'fetchall'} eq '0');
	push(@rv, "\tssl") if ($u->{'ssl'} eq '1');
	push(@rv, "\tno ssl") if ($u->{'ssl'} eq '0');
	push(@rv, "\tpreconnect \"$u->{'preconnect'}\"")
		if ($u->{'preconnect'});
	push(@rv, "\tpostconnect \"$u->{'postconnect'}\"")
		if ($u->{'postconnect'});
	push(@rv, "\t".join(" ", map { /^\S+$/ ? $_ : "\"$_\"" }
			     @{$u->{'unknown'}})) if (@{$u->{'unknown'}});
	}

return @rv;
}

# can_edit_user(user)
sub can_edit_user
{
local %umap;
map { $umap{$_}++; } split(/\s+/, $access{'users'});
if ($access{'mode'} == 1 && !$umap{$_[0]} ||
    $access{'mode'} == 2 && $umap{$_[0]}) { return 0; }
elsif ($access{'mode'} == 3) {
	return $remote_user eq $_[0];
	}
else {
	return 1;
	}
}

# get_fetchmail_version([&out])
sub get_fetchmail_version
{
local $out = &backquote_command("$config{'fetchmail_path'} -V 2>&1 </dev/null");
${$_[0]} = $out if ($_[0]);
return $out =~ /fetchmail\s+release\s+(\S+)/ ? $1 : undef;
}

# show_polls(&polls, file, user)
sub show_polls
{
if (@{$_[0]}) {
	print &ui_columns_start([ $text{'index_poll'},
				  $text{'index_active'},
				  $text{'index_proto'},
				  $text{'index_users'} ], 100);
	foreach $p (@{$_[0]}) {
		local @cols;
		push(@cols, "<a href='edit_poll.cgi?file=$_[1]&".
		      	    "idx=$p->{'index'}&user=$_[2]'>".
			    &html_escape($p->{'poll'})."</a>");
		push(@cols, $p->{'skip'} ?
		    "<font color=#ff0000>$text{'no'}</font>" : $text{'yes'});
		push(@cols, $p->{'proto'} ? &html_escape(uc($p->{'proto'}))
					  : $text{'default'});
		local $ulist;
		foreach $u (@{$p->{'users'}}) {
			$ulist .= sprintf "%s -> %s<br>\n",
				&html_escape($u->{'user'}),
				&html_escape(@{$u->{'is'}} ?
				   join(" ", @{$u->{'is'}}) : $_[2]);
			}
		push(@cols, $ulist);
		print &ui_columns_row(\@cols);
		}
	print &ui_columns_end();
	}
local @links = (
  &ui_link("edit_poll.cgi?new=1&file=$_[1]&user=$_[2]",$text{'index_add'}),
  &ui_link("edit_global.cgi?file=$_[1]&user=$_[2]",$text{'index_global'})
	);
if (@{$_[0]}) {
	push(@links, &ui_link("check.cgi?file=$_[1]&user=$_[2]",$text{'index_run'}));
	}
print &ui_links_row(\@links);
}


1;

