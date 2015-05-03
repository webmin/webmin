# Functions for editing /etc/mailcap

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

if ($module_info{'usermin'}) {
	&switch_to_remote_user();
	&create_user_config_dirs();
	$mailcap_file = $userconfig{'mailcap'};
	if ($mailcap_file !~ /^\//) {
		$mailcap_file = "$remote_user_info[7]/$mailcap_file";
		}
	}
else {
	$mailcap_file = $config{'mailcap'};
	}

# list_mailcap()
# Returns a list of /etc/mailcap entries
sub list_mailcap
{
if (!scalar(@list_mailcap_cache)) {
  @list_mailcap_cache = ( );
  open(CAP, $mailcap_file);
  local $lnum = 0;
  while(<CAP>) {
	  local ($slnum, $elnum) = ($lnum, $lnum);
	  s/\r|\n//g;
	  while (/^(.*)\\/) {
		# Continuation line! Read the next one and append it
		local $before = $1;
		local $nxt = <CAP>;
		$nxt =~ s/\r|\n//g;
		$_ = $before.$nxt;
		$elnum++;
		}
	  if (/^(#*)\s*([a-z0-9\-]+)\/([a-z0-9\-\*]+);\s*([^;]*)(;(.*))?/) {
		  # Found a line
		  local @cmtlines = split(/\n/, $cmt);
		  local $cap = { 'type' => $2."/".$3,
				 'program' => $4,
				 'enabled' => !$1,
				 'cmt' => $cmt,
				 'args' => { },
				 'line' => $slnum-scalar(@cmtlines),
				 'eline' => $elnum,
				 'index' => scalar(@list_mailcap_cache),
			       };
		  # Parse ; separated args after the command
		  local $args = $6;
		  local @args = split(/\s*;\s*/, $args);
		  foreach my $arg (@args) {
			if ($arg =~ /^\s*(\S+)\s*=\s*(.*)/) {
				# A name-value arg
				$cap->{'args'}->{$1} = $2;
				}
			elsif ($arg =~ /^\s*(\S+)\s*$/) {
				$cap->{'args'}->{$1} = "";
				}
			}
		  push(@list_mailcap_cache, $cap);
		  $cmt = undef;
		  }
	  elsif (/^#+(.*)/) {
		  # Found a comment before a rule
		  if ($cmt) {
			$cmt .= "\n".$1;
			}
		  else {
			$cmt = $1;
			}
		  }
	  else {
		  $cmt = undef;
		  }
	  $lnum++;
	  }
  close(CAP);
  }
return @list_mailcap_cache;
}

# create_mailcap(&mailcap)
# Adds a mailcap entry
sub create_mailcap
{
local ($mailcap) = @_;
&list_mailcap();  # init cache
local $lref = &read_file_lines($mailcap_file);
local @lines = &mailcap_lines($mailcap);
$mailcap->{'line'} = scalar(@$lref);
$mailcap->{'eline'} = scalar(@$lref)+scalar(@lines)-1;
$mailcap->{'index'} = scalar(@list_mailcap_cache);
push(@$lref, @lines);
&flush_file_lines($mailcap_file);
push(@list_mailcap_cache, $mailcap);
}

# modify_mailcap(&mailcap)
# Updates one mailcap entry in the file
sub modify_mailcap
{
local ($mailcap) = @_;
local $lref = &read_file_lines($mailcap_file);
local @lines = &mailcap_lines($mailcap);
local $oldlen = $mailcap->{'eline'} - $mailcap->{'line'} + 1;
splice(@$lref, $mailcap->{'line'}, $oldlen, @lines);
&flush_file_lines($mailcap_file);
local $diff = scalar(@lines)-$oldlen;
foreach my $c (grep { $c ne $mailcap } @list_mailcap_cache) {
  $c->{'line'} += $diff if ($c->{'line'} > $mailcap->{'line'});
  $c->{'eline'} += $diff if ($c->{'eline'} > $mailcap->{'line'});
  }
}

# delete_mailcap(&mailcap)
# Removes one mailcap entry from the file
sub delete_mailcap
{
local ($mailcap) = @_;
local $lref = &read_file_lines($mailcap_file);
local $len = $mailcap->{'eline'} - $mailcap->{'line'} + 1;
splice(@$lref, $mailcap->{'line'}, $len);
&flush_file_lines($mailcap_file);
@list_mailcap_cache = grep { $_ ne $mailcap } @list_mailcap_cache;
foreach my $c (@list_mailcap_cache) {
  $c->{'line'} -= $len if ($c->{'line'} > $mailcap->{'line'});
  $c->{'eline'} -= $len if ($c->{'eline'} > $mailcap->{'line'});
  $c->{'index'}-- if ($c->{'index'} > $mailcap->{'index'});
  }
}

# mailcap_lines(&mailcap)
# Returns an array of lines for a mailcap entry
sub mailcap_lines
{
local ($mailcap) = @_;
local @rv;
local $args;
foreach my $a (keys %{$mailcap->{'args'}}) {
	local $v = $mailcap->{'args'}->{$a};
	if ($v eq '') {
		$args .= "; $a";
		}
	else {
		$args .= "; $a=$v";
		}
	}
foreach my $l (split(/\n/, $mailcap->{'cmt'})) {
	push(@rv, "#$l");
	}
push(@rv, ($mailcap->{'enabled'} ? "" : "#").
          "$mailcap->{'type'}; $mailcap->{'program'}".$args);
return @rv;
}

1;

