# firewall-lib.pl
# Unified functions for firewall4-lib and firewall6-lib 
# has to be included from every perl and cgi script
# cgi scripts has also to include firewall4/6-lib based on result of get_ipvx_version() 

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

$config{'perpage'} ||= 50;	# a value of 0 can cause problems

# provide default values if only firewall-lib is included, e.g. foreign_require(firewall, firewall-lib.pl) calls
set_ipvx_version(get_ipvx_version());

# set_ipvx_version(version)
# version can be ipv6 or ipv4,
sub set_ipvx_version
{
$ipvx_save=$iptables_save_file;
$ipvx_lib='firewall4-lib.pl';
$ipv4_link='../firewall/';
$ipv6_link='../firewall6/';
$ipvx_icmp="";
$ipvx_arg="inet4";

if ($_[0] =~ /6$/i) {
	$ipvx='6';
	$ipvx_save=$ip6tables_save_file;
	$ipvx_lib='firewall6-lib.pl';
	$ipvx_icmp="v6";
        $ipvx_arg="inet6";
	}
}

# get_ipvx_version
# get iptables version used from environment
# if script runs in firewall6 or version=inet6, 6 is returned, else 4
sub get_ipvx_version
{
if ( $in{'version'} =~ /6$/ || $module_name =~ /6$/)
	{ return 6; }
return 4;
}


# get_iptables_save([file])
# Parse the iptables save file into a list of tables 
# format seems to be:
#  *table
#  :chain defaultpolicy
#  -A chain options
#  -N chain
#  COMMIT
sub get_iptables_save
{
local (@rv, $table, %got);
local $lnum = 0;

open(FILE, $_[0] || ($config{"direct${ipvx}"} ? "ip${ipvx}tables-save 2>/dev/null |"
				       : $ipvx_save));
local $cmt;
LINE:
while(<FILE>) {
        local $read_comment;
        s/\r|\n//g;
        # regex to filter out chains not managed by firewall, i.e. fail2ban
        if ($config{"direct${ipvx}"} && $config{'filter_chain'}) {
             foreach $filter (split(',', $config{'filter_chain'})) {
                 # NOTE: keep ":chain ..." as reference to avoid error when rebuild active config
                 # -A|-I chain ... -j chain -> skip line if machtes filter_chain
                 if (/^.?-(A|I)\s+(\S+).*\s+-j\s+(.*)/) {
                         next LINE if($2 =~ /^$filter$/);
                    }
                }
            }
	if (s/#\s*(.*)$//) {
		$cmt .= " " if ($cmt);
		$cmt .= $1;
		$read_comment=1;
		}
	if (/^\*(\S+)/) {
		# Start of a new table
		$got{$1}++;
		push(@rv, $table = { 'line' => $lnum,
				     'eline' => $lnum,
				     'name' => $1,
				     'rules' => [ ],
				     'defaults' => { } });
		}
	elsif (/^:(\S+)\s+(\S+)/) {
		# Default policy definition
		$table->{'defaults'}->{$1} = $2;
		}
	elsif (/^(\[[^\]]*\]\s+)?-N\s+(\S+)(.*)/) {
		# New chain definition
		$table->{'defaults'}->{$2} = '-';
		}
	elsif (/^(\[[^\]]*\]\s+)?-(A|I)\s+(\S+)(.*)/) {
		# Rule definition
		local $rule = { 'line' => $lnum,
				'eline' => $lnum,
				'index' => scalar(@{$table->{'rules'}}),
				'cmt' => $cmt,
				'chain' => $3,
				'args' => $4 };
		if ($2 eq "I") {
			unshift(@{$table->{'rules'}}, $rule);
			}
		else {
			push(@{$table->{'rules'}}, $rule);
			}

		# Parse arguments
		foreach $a (@known_args) {
			local @vl;
			while($rule->{'args'} =~
			       s/\s+(!?)\s*($a)\s+(!?)\s*("[^"]*")(\s+|$)/ / ||
			      $rule->{'args'} =~
                               s/\s+(!?)\s*($a)\s+(!?)\s*('[^']*')(\s+|$)/ / ||
			      $rule->{'args'} =~
			       s/\s+(!?)\s*($a)\s+(!?)\s*(([^ \-!]\S*(\s+|$))+)/ / ||
			      $rule->{'args'} =~
			       s/\s+(!?)\s*($a)()(\s+|$)/ /) {
				push(@vl, [ $1 || $3, &split_quoted_string($4) ]);
				}
			local ($aa = $a); $aa =~ s/^-+//;
			if ($a eq '-m') {
				$rule->{$aa} = \@vl if (@vl);
				}
			else {
				$rule->{$aa} = $vl[0];
				}
			}
		}
	elsif (/^COMMIT/) {
		# Marks end of a table
		$table->{'eline'} = $lnum;
		}
	elsif (/\S/) {
		&error(&text('eiptables', "<tt>$_</tt>"));
		}
	$lnum++;
	if (! defined($read_comment)) { $cmt=undef; }
	}
close(FILE);
@rv = sort { $a->{'name'} cmp $b->{'name'} } @rv;
local $i;
map { $_->{'index'} = $i++ } @rv;
return @rv;
}

# save_table(&table)
# Updates an existing IPtable in the save file
sub save_table
{
local $lref;
if ($config{"direct${ipvx}"}) {
	# Read in the current iptables-save output
	$lref = &read_file_lines("ip${ipvx}tables-save 2>/dev/null |", 1);
	}
else {
	# Updating the save file
	$lref = &read_file_lines($ipvx_save);
	}
local @lines = ( "*$_[0]->{'name'}" );
local ($d, $r);
foreach $d (keys %{$_[0]->{'defaults'}}) {
	push(@lines, ":$d $_[0]->{'defaults'}->{$d} [0:0]");
	}
foreach $r (@{$_[0]->{'rules'}}) {
	local $line;
	$line = "# $r->{'cmt'}\n" if ($r->{'cmt'});
	$line .= "-A $r->{'chain'}";
	foreach $a (@known_args) {
		local ($aa = $a); $aa =~ s/^-+//;
		if ($r->{$aa}) {
			local @al = ref($r->{$aa}->[0]) ?
					@{$r->{$aa}} : ( $r->{$aa} );
			foreach $ag (@al) {
				local $n = shift(@$ag);
				local @w = ( $n ? ( $n ) : (), $a, @$ag );
				@w = map { $_ =~ /'/ ? "\"$_\"" :
					   $_ =~ /"/ ? "'".$_."'" :
					   $_ =~ /\s/ ? "\"$_\"" : $_ } @w;
				$line .= " ".join(" ", @w);
				}
			}
		}
	$line .= " $r->{'args'}" if ($r->{'args'} =~ /\S/);
	push(@lines, $line);
	}
push(@lines, "COMMIT");
if (defined($_[0]->{'line'})) {
	# Update in file
	splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1,
	       @lines);
	}
else {
	# Append new table to file
	push(@$lref, "# Generated by webmin", @lines, "# Completed");
	}
if ($config{"direct${ipvx}"}) {
	# Pass new lines to iptables-restore
	open(SAVE, "| ip${ipvx}tables-restore");
	print SAVE map { $_."\n" } @$lref;
	close(SAVE);
	}
else {
	# Just save the file
	&flush_file_lines();
	}
}

# get_ipsets_active()
# return a list of active ipsets
sub get_ipsets_active
{
local (@rv, $name, $set={});
open(FILE, "ipset list -t 2>/dev/null |");
LINE:
while(<FILE>) {
      # remove newlines, get arg and value
        s/\r|\n//g;
      local ($n, $v) = split(/: /, $_);
      ($n) = $n =~ /(\S+)/;
      # get values from name to number
      $name=$v if ($n eq "Name");
      $set->{$n}=$v;
      if ($n eq "Number") {
               push(@rv, $set);
               $set={};
              }
      }
return @rv;
}


# describe_rule(&rule)
# Returns a human-readable description of some rule conditions
sub describe_rule
{
local (@c, $d);
foreach $d ('p', 's', 'd', 'i', 'o', 'f', 'dport',
	    'sport', 'tcp-flags', 'tcp-option',
	    'icmp-type', 'icmpv6-type', 'mac-source', 'limit', 'limit-burst',
	    'ports', 'uid-owner', 'gid-owner',
	    'pid-owner', 'sid-owner', 'state', 'ctstate', 'tos',
	    'dports', 'sports', 'physdev-in', 'physdev-out', 'args') {
	if ($_[0]->{$d}) {

		# get name and values
		local ($n, @v) = @{$_[0]->{$d}};
		# with additional args
		if ($d eq 'args') {
			# get args
			@v = grep {/\S/} split(/ / , $_[0]->{$d});
			# first arg is name, next are values
			$n=shift(@v);
			# translate src and dest parameter for ipset
			push(@v, &text("desc_". pop(@v))) if ($n eq "--match-set");
			} 
		# uppercase for p
		@v = map { uc($_) } @v if ($d eq 'p');
		# merge all in one for s and d
		@v = map { join(", ", split(/,/, $_)) } @v if ($d eq 's' || $d eq 'd' );
		# compose desc_$n$d to get localized message, provide values as $1, ..., $n
		local $txt = &text("desc_$d$n", map { "<strong>$_</strong>" } @v);
		push(@c, $txt) if ($txt);
		}
	}
local $rv;
if (@c) {
	$rv = &text('desc_conds', join(" $text{'desc_and'} ", @c));
	}
else {
	$rv = $text{'desc_always'};
	}
return $rv;
}

# create_firewall_init()
# Do whatever is needed to have the firewall started at boot time
sub create_firewall_init
{
if (defined(&enable_at_boot)) {
	# Use distro's function
	&enable_at_boot();
	}
else {
	# May need to create init script
	&create_webmin_init();
	}
}

# create_webmin_init()
# Create (if necessary) the Webmin iptables init script
sub create_webmin_init
{
local $res = &has_command("ip${ipvx}tables-restore");
local $ipt = &has_command("ip${ipvx}tables");
local $start = "$res <$ipvx_save";
local $stop = "$ipt -t filter -F\n".
	      "$ipt -t nat -F\n".
	      "$ipt -t mangle -F\n".
	      "$ipt -t filter -P INPUT ACCEPT\n".
	      "$ipt -t filter -P OUTPUT ACCEPT\n".
	      "$ipt -t filter -P FORWARD ACCEPT\n".
	      "$ipt -t nat -P PREROUTING ACCEPT\n".
	      "$ipt -t nat -P POSTROUTING ACCEPT\n".
	      "$ipt -t nat -P OUTPUT ACCEPT\n".
	      "$ipt -t mangle -P PREROUTING ACCEPT\n".
	      "$ipt -t mangle -P OUTPUT ACCEPT";
&foreign_require("init", "init-lib.pl");
&init::enable_at_boot("webmin-ip${ipvx}tables", "Load ip${ipvx}tables save file",
		      $start, $stop, undef, { 'exit' => 1 });
}

# interface_choice(name, value)
sub interface_choice
{
local ($name, $value) = @_;
local @ifaces;
if (&foreign_check("net")) {
	&foreign_require("net", "net-lib.pl");
	return &net::interface_choice($name, $value, undef, 0, 1);
	}
else {
	return &ui_textbox($name, $value, 6);
	}
}

sub check_previous
{
	my (@p,$max,$n)=@_;
	for ($i=0;$i<$max;$i++)
	{
		if ($n eq $p[$i]){return 1}
	}
	return -1;
}
 
sub by_string_for_iptables
{
	my @p=("PREROUTING","INPUT","FORWARD","OUTPUT","POSTROUTING");

	for ($i=0;$i<@p;$i++)
	{
		if ($a eq $p[$i]){
			if (&check_previous(@p,$i,$b)){return -1;}
			else{ return 1;}}
		if ($b eq $p[$i]){
			if (&check_previous(@p,$i,$b)){return 1;}
			else{ return -1;}}
	}

	return $a cmp $b;
}

sub missing_firewall_commands
{
local $c;
foreach $c ("ip${ipvx}tables", "ip${ipvx}tables-restore", "ip${ipvx}tables-save") {
	return $c if (!&has_command($c));
	}
return undef;
}

# iptables_restore()
# Activates the current firewall rules, and returns any error
sub iptables_restore
{
local $rcmd = &has_command("ip${ipvx}tables-legacy-restore") ||
	      "ip${ipvx}tables-restore";
local $out = &backquote_logged("cd / && $rcmd <$ipvx_save 2>&1");
return $? ? "<pre>$out</pre>" : undef;
}

# iptables_save()
# Saves the active firewall rules, and returns any error
sub iptables_save
{
local $scmd = &has_command("ip${ipvx}tables-legacy-save") ||
	      "ip${ipvx}tables-save";
local $out = &backquote_logged("$scmd >$ipvx_save 2>&1");
return $? ? "<pre>$out</pre>" : undef;
}

# can_edit_table(name)
sub can_edit_table
{
return $access{$_[0]};
}

# can_jump(jump|&rule)
sub can_jump
{
return 1 if (!$access{'jumps'});
if (!%can_jumps_cache) {
	%can_jumps_cache = map { lc($_), 1 } split(/\s+/, $access{'jumps'});
	}
local $j = ref($_[0]) ? $_[0]->{'j'}->[1] : $_[0];
return 1 if (!$j);	# always allow 'do nothing'
return $can_jumps_cache{lc($j)};
}

# run_before_command()
# Runs the before-saving command, if any
sub run_before_command
{
if ($config{'before_cmd'}) {
	&system_logged("($config{'before_cmd'}) </dev/null >/dev/null 2>&1");
	}
}

# run_after_command()
# Runs the after-saving command, if any
sub run_after_command
{
if ($config{'after_cmd'}) {
	&system_logged("($config{'after_cmd'}) </dev/null >/dev/null 2>&1");
	}
}

# run_before_apply_command()
# Runs the before-applying command, if any. If it failes, returns the error
# message output
sub run_before_apply_command
{
if ($config{'before_apply_cmd'}) {
	local $out = &backquote_logged("($config{'before_apply_cmd'}) </dev/null 2>&1");
	return $out if ($?);
	}
return undef;
}

# run_after_apply_command()
# Runs the after-applying command, if any
sub run_after_apply_command
{
if ($config{'after_apply_cmd'}) {
	&system_logged("($config{'after_apply_cmd'}) </dev/null >/dev/null 2>&1");
	}
}

# apply_configuration()
# Calls all the appropriate apply functions and programs, and returns an error
# message if anything fails
sub apply_configuration
{
local $err = &run_before_apply_command();
return $err if ($err);
if (defined(&apply_iptables)) {
	# Call distro's apply command
	$err = &apply_iptables();
	}
else {
	# Manually run iptables-restore
	$err = &iptables_restore();
	}
return $err if ($err);
&run_after_apply_command();
return undef;
}

# list_cluster_servers()
# Returns a list of servers on which the firewall is managed
sub list_cluster_servers
{
&foreign_require("servers", "servers-lib.pl");
local %ids = map { $_, 1 } split(/\s+/, $config{'servers'});
return grep { $ids{$_->{'id'}} } &servers::list_servers();
}

# add_cluster_server(&server)
sub add_cluster_server
{
local @sids = split(/\s+/, $config{'servers'});
$config{'servers'} = join(" ", @sids, $_[0]->{'id'});
&save_module_config();
}

# delete_cluster_server(&server)
sub delete_cluster_server
{
local @sids = split(/\s+/, $config{'servers'});
$config{'servers'} = join(" ", grep { $_ != $_[0]->{'id'} } @sids);
&save_module_config();
}

# server_name(&server)
sub server_name
{
return $_[0]->{'desc'} ? $_[0]->{'desc'} : $_[0]->{'host'};
}

# copy_to_cluster([force])
# Copy all firewall rules from this server to those in the cluster
sub copy_to_cluster
{
return if (!$config{'servers'});		# no servers defined
return if (!$_[0] && $config{'cluster_mode'});	# only push out when applying
local $s;
local $ltemp;
if ($config{"direct${ipvx}"}) {
	# Dump current configuration
	$ltemp = &transname();
	system("ip${ipvx}tables-save >$ltemp 2>/dev/null");
	}
foreach $s (&list_cluster_servers()) {
	&remote_foreign_require($s, $module_name);
	if ($config{"direct${ipvx}"}) {
		# Directly activate on remote server!
		local $rtemp = &remote_write($s, $ltemp);
		unlink($ltemp);
		local $err = &remote_eval($s, $module_name,
		  "\$out = `ip${ipvx}tables-restore <$rtemp 2>&1`; [ \$out, \$? ]"); 
		&remote_foreign_call($s, $module_name, "unlink_file", $rtemp);
		&error(&text('apply_remote', $s->{'host'}, $err->[0]))
			if ($err->[1]);
		}
	else {
		# Can just copy across save file
		local $rfile = &remote_eval($s, $module_name,
					    "\$ip${ipvx}tables_save_file");
		&remote_write($s, $ipvx_save, $rfile);
		}
	}
}

# apply_cluster_configuration()
# Activate the current configuration on all servers in the cluster
sub apply_cluster_configuration
{
return undef if (!$config{'servers'});
if ($config{'cluster_mode'}) {
	&copy_to_cluster(1);
	}
local $s;
foreach $s (&list_cluster_servers()) {
	&remote_foreign_require($s->{'host'}, $module_name);
	local $err = &remote_foreign_call(
		$s->{'host'}, $module_name, "apply_configuration");
	if ($err) {
		return &text('apply_remote', $s->{'host'}, $err);
		}
	}
return undef;
}

# validate_iptables_config()
# Tests that the rules file can be parsed
sub validate_iptables_config
{
my $out = &backquote_command(
	"ip${ipvx}tables-restore --test <$ipvx_save 2>&1");
return undef if (!$?);
$out =~ s/Try\s.*more\s+information.*//;
return $out;
}

sub supports_conntrack
{
if (!defined($supports_conntrack_cache)) {
	my $out = &backquote_command("uname -r 2>/dev/null");
	$supports_conntrack_cache = $out =~ /^[3-9]\./ ? 1 : 0;
	}
return $supports_conntrack_cache;
}

1;

