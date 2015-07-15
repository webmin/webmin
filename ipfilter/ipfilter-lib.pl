# Functions for parsing ipf.conf

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
&foreign_require("net", "net-lib.pl");

# Get the detected ipf version
if (open(VERSION, "$module_config_directory/version")) {
	chop($ipf_version = <VERSION>);
	close(VERSION);
	}

@actions = ( "block", "pass", "log", "count", "skip", "auth", "preauth", "call" );
@compare_ops = ( "=", "!=", "<", ">", "<=", ">=", "eq", "ne", "lt", "gt", "le", "ge" );
@icmp_codes = ( "net-unr" , "host-unr" , "proto-unr" , "port-unr" ,
            "needfrag" , "srcfail" , "net-unk" , "host-unk" , "isolate" ,
            "net-prohib" , "host-prohib" , "net-tos" , "host-tos" ,
            "filter-prohib" , "host-preced" , "cutoff-preced" );
@log_priorities = ( "emerg" , "alert" , "crit" , "err" , "warn" , "notice" , "info" , "debug" );
@log_facilities = ( "kern" , "user" , "mail" , "daemon" , "auth" , "syslog" ,
            "lpr" , "news" , "uucp" , "cron" , "ftp" , "authpriv" ,
            "audit" , "logalert" , "local0" , "local1" , "local2" ,
            "local3" , "local4" , "local5" , "local6" , "local7" );
@icmp_types = ( "unreach" , "echo" , "echorep" , "squench" , "redir" ,
            "timex" , "paramprob" , "timest" , "timestrep" , "inforeq" ,
            "inforep" , "maskreq" , "maskrep" );

$init_script = $config{'init'} || "webmin-$module_name";

sub missing_firewall_commands
{
local $cmd;
foreach $cmd ("ipf", "ipfstat", "ipnat") {
	if (!&has_command($config{$cmd})) {
		return $config{$cmd};
		}
	}
return undef;
}

# get_config([file])
# Parse the ipfilter config file
sub get_config
{
local $file = $_[0] || $config{'ipf_conf'};
return $get_config_cache{$file} if ($get_config_cache{$file});
local @rv;
local $lnum = 0;
open(FILE, $file);
while(<FILE>) {
	# Read each line, splitting into words
	s/\r|\n//g;
	if (/^\s*(#*)\s*((block|pass|log|count|skip|auth|preauth|call|\@).*)$/) {
		# A rule, perhaps commented
		local $nocmt = $2;
		local @w = split(/\s+/, $nocmt);
		local @cmts = split(/\n/, $cmt);
		local $rule = { 'index' => scalar(@rv),
				'type' => 'ipf',
				'line' => $lnum-scalar(@cmts),
				'eline' => $lnum,
				'file' => $file,
				'text' => $_,
				'cmt' => $cmt,
				'active' => !$1 };
		$cmt = undef;

		# There can be a special insert prefix
		if ($w[0] eq "\@") {
			shift(@w);
			$rule->{'insert'} = shift(@w);
			}

		# First word is the action, possibly with an arg
		$rule->{'action'} = shift(@w);
		if ($rule->{'action'} eq "block") {
			# Block can have ICMP return type parameter
			print STDERR $w[0],"\n";
			if ($w[0] eq "return-rst") {
				shift(@w);
				$rule->{'block-return'} = "rst";
				}
			elsif ($w[0] eq "return-icmp" ||
			       $w[0] eq "return-icmp-as-dest") {
				# Handle action like return-icmp ( net-unr )
				$rule->{'block-return-dest'} = 1
					if ($w[0] eq "return-icmp-as-dest");
				shift(@w);
				shift(@w);	# skip (
				$rule->{'block-return'} = shift(@w);
				shift(@w);	# skip )
				}
			elsif ($w[0] =~ /^(return-icmp|return-icmp-as-dest)\((\S+)\)/) {
				# Same as above, with no spaces
				$rule->{'block-return-dest'} = 1
					if ($1 eq "return-icmp-as-dest");
				$rule->{'block-return'} = $2;
				shift(@w);
				}
			}
		elsif ($rule->{'action'} eq "log") {
			# Log action can have several options
			&parse_log("log");
			}
		elsif ($rule->{'action'} eq "skip") {
			# Skip action specifies rule number
			$rule->{'skip'} = shift(@w);
			}
		elsif ($rule->{'action'} eq "call") {
			# Call action has a function name
			if ($w[0] eq "now") {
				$rule->{'call-now'} = shift(@w);
				}
			$rule->{'call'} = shift(@w);
			}

		# Second is 'in' or 'out'
		$rule->{'dir'} = shift(@w);

		# Parse options
		while(1) {
			if ($w[0] eq "log") {
				# Log option has several sub-options!
				shift(@w);
				$rule->{'olog'} = 1;
				&parse_log("olog");
				}
			elsif ($w[0] eq "tag") {
				# Tag has ID option
				shift(@w);
				$rule->{'tag'} = shift(@w);
				}
			elsif ($w[0] eq "quick") {
				shift(@w);
				$rule->{'quick'} = 1;
				}
			elsif ($w[0] eq "on") {
				# On some interface name
				shift(@w);
				$rule->{'on'} = shift(@w);
				}
			elsif ($w[0] eq "dup-to") {
				# Has interface:ip option
				shift(@w);
				$rule->{'dup-to'} = shift(@w);
				}
			elsif ($w[0] eq "fastroute" || $w[0] eq "to") {
				# Fastroute option has interface name (and IP)
				shift(@w);
				$rule->{'fastroute'} = shift(@w);
				if ($w[0] eq ":") {
					shift(@w);
					$rule->{'fastroute-ip'} = shift(@w);
					}
				}
			elsif ($w[0] eq "reply-to") {
				# Replyto option has interface name (and IP)
				shift(@w);
				$rule->{'reply-to'} = shift(@w);
				if ($w[0] eq ":") {
					shift(@w);
					$rule->{'reply-to-ip'} = shift(@w);
					}
				}
			else {
				last;
				}
			}

		# Parse TOS
		if ($w[0] eq "tos") {
			shift(@w);
			$rule->{'tos'} = shift(@w);
			}

		# Parse TTL
		if ($w[0] eq "ttl") {
			shift(@w);
			$rule->{'ttl'} = shift(@w);
			}

		# Inet keyword can appear before proto, but does nothing
		if ($w[0] eq "inet") {
			shift(@w);
			}

		# Parse protocol
		if ($w[0] eq "proto") {
			shift(@w);
			$rule->{'proto'} = shift(@w);
			}

		# Skip inet keyword, which as far as I know does nothing
		if ($w[0] eq "inet") {
			shift(@w);
			}

		# Parse from/to section
		if ($w[0] eq "all") {
			shift(@w);
			$rule->{'all'} = 1;
			}
		elsif ($w[0] eq "from") {
			shift(@w);	# skip 'from'
			&parse_object("from");
			shift(@w);	# skip 'to'
			&parse_object("to");
			}
		else {
			if (!$rule->{'active'}) {
				# Must actually be a comment!
				$cmt .= "\n" if ($cmt);
				$cmt .= $nocmt;
				goto nextline;
				}
			&error("error parsing IPF line $_ at $w[0] line $lnum ".
			       " : remainder ".join(" ", @w));
			}

		# Parse ip options
		if ($w[0] eq "flags") {
			shift(@w);
			$rule->{'flags1'} = shift(@w);
			if ($w[0] eq "/") {
				shift(@w);
				$rule->{'flags2'} = shift(@w);
				}
			}
		if ($w[0] eq "with" || $w[0] eq "and") {
			# Just store keywords till end of section
			shift(@w);
			local @with;
			while(@w && $w[0] ne "keep" && $w[0] ne "icmp-type" &&
			      $w[0] ne "head" && $w[0] ne "group") {
				push(@with, shift(@w));
				}
			$rule->{'with'} = \@with;
			}
		if ($w[0] eq "icmp-type") {
			shift(@w);
			$rule->{'icmp-type'} = shift(@w);
			if ($w[0] eq "code") {
				shift(@w);
				$rule->{'icmp-type-code'} = shift(@w);
				}
			}
		if ($w[0] eq "keep") {
			shift(@w);
			$rule->{'keep'} = shift(@w);
			}

		# Parse group section
		if ($w[0] eq "head") {
			shift(@w);
			$rule->{'head'} = shift(@w);
			}
		elsif ($w[0] eq "group") {
			shift(@w);
			$rule->{'group'} = shift(@w);
			}

		push(@rv, $rule);
		}
	elsif (/^\s*#\s*(.*)$/) {
		# A comment line
		$cmt .= "\n" if ($cmt);
		$cmt .= $1;
		}
	nextline:
	$lnum++;
	}
close(FILE);
$get_config_cache{$file} = \@rv;
return $get_config_cache{$file};
}

# get_live_config()
# Returns all active firewall rules
sub get_live_config
{
local $livein = &get_config("$config{'ipfstat'} -i |");
local $liveout = &get_config("$config{'ipfstat'} -o |");
return [ @$livein, @$liveout ];
}

# parse_log(suffix)
sub parse_log
{
local $pfx = $_[0];
while(1) {
	if ($w[0] eq "body") {
		shift(@w);
		$rule->{$pfx.'-body'} = 1;
		}
	elsif ($w[0] eq "first") {
		shift(@w);
		$rule->{$pfx.'-first'} = 1;
		}
	elsif ($w[0] eq "or-block") {
		shift(@w);
		$rule->{$pfx.'-or-block'} = 1;
		}
	elsif ($w[0] eq "level") {
		shift(@w);
		$rule->{$pfx.'-level'} = shift(@w);
		}
	else {
		last;
		}
	}
}

# parse_object(direction)
sub parse_object
{
local $dir = $_[0];

# Parse ! prefix
if ($w[0] eq "!") {
	shift(@w);
	$rule->{$dir."-not"} = 1;
	}

# Parse addr section
local $addr = shift(@w);
if ($addr eq "any") {
	$rule->{$dir."-any"} = 1;
	}
elsif ($addr eq "<thishost>") {
	$rule->{$dir."-thishost"} = 1;
	}
elsif ($addr =~ /^(\S+)\/(\S+)$/) {
	# host-name/number
	$rule->{$dir."-numhost"} = $1;
	$rule->{$dir."-nummask"} = $2;
	}
elsif (@w > 0 && $w[0] eq "/") {
	# host-name [ "/" decnumber ]
	$rule->{$dir."-numhost"} = $addr;
	shift(@w);
	$rule->{$dir."-nummask"} = shift(@w);
	}
else {
	# host-name [ "mask" ipaddr | "mask" hexnumber ]
	$rule->{$dir."-host"} = $addr;
	if (@w && $w[0] eq "mask") {
		shift(@w);
		$rule->{$dir."-mask"} = shift(@w);
		}
	}

# Parse port-comp or port-range
if ($w[0] eq "port") {
	shift(@w);
	if (&indexof($w[0], @compare_ops) >= 0) {
		# Must be port-comp
		$rule->{$dir.'-port-comp'} = shift(@w);
		$rule->{$dir.'-port-num'} = shift(@w);
		}
	else {
		# Must be port-range
		$rule->{$dir.'-port-start'} = shift(@w);
		$rule->{$dir.'-port-range'} = shift(@w);
		$rule->{$dir.'-port-end'} = shift(@w);
		}
	}
}

# interface_choice(name, value, noignored, disabled?)
sub interface_choice
{
local @ifaces;
if (&foreign_check("net")) {
	&foreign_require("net", "net-lib.pl");
	return &net::interface_choice($_[0], $_[1],
			      $_[2] ? undef : $text{'edit_anyiface'}, $_[3]);
	}
else {
	return &ui_textbox($_[0], $_[1], 6, $_[3]);
	}
}

# parse_interface_choice(name, error)
sub parse_interface_choice
{
local $rv = $in{$_[0]} eq "other" ? $in{$_[0]."_other"} : $in{$_[0]};
$rv =~ /^[a-z]+\d*/ || &error($_[1]);
return $rv;
}

# describe_rule(&rule, where-mode)
# Returns a human-readable description for the conditions for some rule
sub describe_rule
{
local $r = $_[0];
local @rv;
if ($r->{'proto'}) {
	push(@rv, &text('desc_proto', "<b>".uc($r->{'proto'})."</b>"));
	}
local $f;
push(@rv, &describe_object($r, "from"));
push(@rv, &describe_object($r, "to"));
if ($r->{'on'}) {
	push(@rv, &text('desc_on', "<b>".$r->{'on'}."</b>"));
	}
return &describe_join(\@rv, $_[1]);
}

# describe_object(&rule, prefix)
sub describe_object
{
local ($r, $f) = @_;
local @rv;
if ($r->{$f.'-thishost'}) {
	push(@rv, &text('desc_'.$f.'_thishost'));
	}
elsif ($r->{$f.'-numhost'} && $r->{$f.'-nummask'} == 32) {
	push(@rv, &text('desc_'.$f, "<b>".$r->{$f.'-numhost'}."</b>"));
	}
elsif ($r->{$f.'-numhost'} && $r->{$f.'-nummask'}) {
	push(@rv, &text('desc_'.$f, "<b>".$r->{$f.'-numhost'}."/".
				    $r->{$f.'-nummask'}."</b>"));
	}
elsif ($r->{$f.'-numhost'}) {
	push(@rv, &text('desc_'.$f, "<b>".$r->{$f.'-numhost'}."</b>"));
	}
elsif ($r->{$f.'-host'} && $r->{$f.'-mask'} eq "255.255.255.255") {
	push(@rv, &text('desc_'.$f, "<b>".$r->{$f.'-host'}."</b>"));
	}
elsif ($r->{$f.'-host'} && $r->{$f.'-mask'}) {
	push(@rv, &text('desc_'.$f, "<b>".$r->{$f.'-host'}."/".
				    $r->{$f.'-mask'}."</b>"));
	}
elsif ($r->{$f.'-host'}) {
	push(@rv, &text('desc_'.$f, "<b>".$r->{$f.'-host'}."</b>"));
	}
if ($r->{$f.'-port-comp'}) {
	push(@rv, &text('desc_portcomp_'.$f,
		$r->{$f.'-port-comp'},
		"<b>".$r->{$f.'-port-num'}."</b>"));
	}
elsif ($r->{$f.'-port-range'} eq '><') {
	push(@rv, &text('desc_portrange_'.$f,
		"<b>".$r->{$f.'-port-start'}."</b>",
		"<b>".$r->{$f.'-port-end'}."</b>"));
	}
elsif ($r->{$f.'-port-range'} eq '<>') {
	push(@rv, &text('desc_portrangenot_'.$f,
		"<b>".$r->{$f.'-port-start'}."</b>",
		"<b>".$r->{$f.'-port-end'}."</b>"));
	}
return @rv;
}

# describe_from(&rule, where-mode)
# Returns a human-readable description of the match part of a NAT rule
sub describe_from
{
local ($r) = @_;
local @rv;
push(@rv, &text('desc_on', "<b>".$r->{'iface'}."</b>"));
if ($r->{'from'}) {
	push(@rv, &describe_object($r, "from"), &describe_object($r, "fromto"));
	}
elsif ($r->{'frommask'} eq '255.255.255.255' || $r->{'frommask'} eq "32") {
	push(@rv, &text('desc_natfromh', "<b>$r->{'fromip'}</b>"));
	}
elsif ($r->{'frommask'} ne '0.0.0.0' && $r->{'frommask'} ne "0") {
	push(@rv, &text('desc_natfrom', "<b>$r->{'fromip'}</b>",
				        "<b>$r->{'frommask'}</b>"));
	}
if ($r->{'dport1'} && $r->{'dport2'}) {
	push(@rv, &text('desc_dport2', "<b>$r->{'dport1'}</b>",
				    "<b>$r->{'dport2'}</b>"));
	}
elsif ($r->{'dport1'}) {
	push(@rv, &text('desc_dport1', "<b>$r->{'dport1'}</b>"));
	}
return &describe_join(\@rv, $_[1]);
}

# describe_to(&rule, where-mode)
# Returns a human-readable description of the translation part of a NAT rule
sub describe_to
{
local ($r, $where) = @_;
local @rv;
if ($r->{'rdrip'}) {
	push(@rv, &text('desc_rdr', "<b>".join(" ", @{$r->{'rdrip'}})."</b>",
				    "<b>".$r->{'rdrport'}."</b>"));
	}
elsif ($r->{'tostart'}) {
	push(@rv, &text('desc_natrange', "<b>$r->{'tostart'}</b>",
				         "<b>$r->{'toend'}</b>"));
	}
elsif ($r->{'toip'} eq '0.0.0.0' && $r->{'tomask'} eq "32") {
	push(@rv, $text{'desc_nattoiface'});
	}
elsif ($r->{'tomask'} eq '255.255.255.255' || $r->{'tomask'} eq "32") {
	push(@rv, &text('desc_nattoh', "<b>$r->{'toip'}</b>"));
	}
else {
	push(@rv, &text('desc_natto', "<b>$r->{'toip'}</b>",
				      "<b>$r->{'tomask'}</b>"));
	}
return &text($where ? 'desc_tolc' : 'desc_touc',
	     join(" $text{'desc_and'} ", @rv));
}

# describe_join(&array, where-mode)
sub describe_join
{
local ($rv, $where) = @_;
return @$rv ? &text($where ? 'desc_where' : 'desc_if',
		   join(" $text{'desc_and'} ", @$rv))
	    : $text{$where ? 'desc_all' : 'desc_always'};
}

# create_rule(&rule)
# Add one rule to the config file, at the end
sub create_rule
{
# Add to file
if ($_[0]->{'type'} eq 'ipnat') {
	$_[0]->{'file'} ||= $config{'ipnat_conf'};
	}
else {
	$_[0]->{'file'} ||= $config{'ipf_conf'};
	}
local $lref = &read_file_lines($_[0]->{'file'});
$_[0]->{'line'} = scalar(@$lref);
local @lines = &rule_lines($_[0]);
$_[0]->{'eline'} = $_[0]->{'line'} + scalar(@lines) - 1;
push(@$lref, @lines);
&flush_file_lines();

# Add to config cache
local $conf = &config_for_rule($_[0]);
$_[0]->{'index'} = scalar(@$conf);
push(@$conf, $_[0]);
}

# insert_rule(&rule, &before)
# Adds one rule to the config file, before some other
sub insert_rule
{
# Add to file
$_[0]->{'file'} ||= $_[1]->{'file'};
$_[0]->{'type'} ||= $_[1]->{'type'};
local $lref = &read_file_lines($_[0]->{'file'});
$_[0]->{'line'} = $_[1]->{'line'};
local @lines = &rule_lines($_[0]);
$_[0]->{'eline'} = $_[0]->{'line'} + scalar(@lines) - 1;
splice(@$lref, $_[0]->{'line'}, 0, @lines);

# Update config cache
local $conf = &config_for_rule($_[0]);
$_[0]->{'index'} = $_[1]->{'index'};
foreach $c (@$conf) {
	$c->{'index'}++ if ($c->{'index'} >= $_[0]->{'index'});
	$c->{'line'} += scalar(@lines) if ($c->{'line'} >= $_[0]->{'line'});
	$c->{'eline'} += scalar(@lines) if ($c->{'eline'} >= $_[0]->{'eline'});
	}
splice(@$conf, $_[0]->{'index'}, 0, $_[0]);
}

# delete_rule(&rule)
# Remove one rule
sub delete_rule
{
# Update file
local $lref = &read_file_lines($_[0]->{'file'});
local $len = $_[0]->{'eline'} - $_[0]->{'line'} + 1;
splice(@$lref, $_[0]->{'line'}, $len);

# Update config cache
local $conf = &config_for_rule($_[0]);
splice(@$conf, $_[0]->{'index'}, 1);
local $c;
foreach $c (@$conf) {
	$c->{'index'}-- if ($c->{'index'} > $_[0]->{'index'});
	$c->{'line'} -= $len if ($c->{'line'} > $_[0]->{'line'});
	$c->{'eline'} -= $len if ($c->{'eline'} > $_[0]->{'eline'});
	}
}

# modify_rule(&rule)
# Update one rule
sub modify_rule
{
# Update file
local $lref = &read_file_lines($_[0]->{'file'});
local @lines = &rule_lines($_[0]);
local $len = $_[0]->{'eline'} - $_[0]->{'line'} + 1;
local $newlen = scalar(@lines);
splice(@$lref, $_[0]->{'line'}, $len, @lines);

# Update config cache
$_[0]->{'eline'} = $_[0]->{'line'} + $newlen - 1;
local $conf = &config_for_rule($_[0]);
local $c;
foreach $c (@$conf) {
	next if ($c eq $_[0]);
	$c->{'line'} += $newlen - $len if ($c->{'line'} > $_[0]->{'line'});
	$c->{'eline'} += $newlen - $len if ($c->{'eline'} > $_[0]->{'eline'});
	}
}

# swap_rules(&rule1, &rule2)
# Swap two rules in the config file, which MUST be next to each other
sub swap_rules
{
local $lref = &read_file_lines($_[0]->{'file'});
local @lines0 = @$lref[$_[0]->{'line'} .. $_[0]->{'eline'}];
local @lines1 = @$lref[$_[1]->{'line'} .. $_[1]->{'eline'}];
if ($_[0]->{'line'} < $_[1]->{'line'}) {
	splice(@$lref, $_[0]->{'line'}, $_[1]->{'eline'}-$_[0]->{'line'}+1,
	       (@lines1, @lines0));
	$_[1]->{'line'} = $_[0]->{'line'};
	$_[1]->{'eline'} = $_[1]->{'line'} + scalar(@lines1) - 1;
	$_[0]->{'line'} = $_[1]->{'eline'}+1;
	$_[0]->{'eline'} = $_[0]->{'line'} + scalar(@lines0) - 1;
	}
else {
	splice(@$lref, $_[1]->{'line'}, $_[0]->{'eline'}-$_[1]->{'line'}+1,
	       (@lines0, @lines1));
	$_[0]->{'line'} = $_[1]->{'line'};
	$_[0]->{'eline'} = $_[0]->{'line'} + scalar(@lines0) - 1;
	$_[1]->{'line'} = $_[0]->{'eline'}+1;
	$_[1]->{'eline'} = $_[1]->{'line'} + scalar(@lines1) - 1;
	}

# Update config cache
($_[0]->{'index'}, $_[1]->{'index'}) = ($_[1]->{'index'}, $_[0]->{'index'});
local $conf = &config_for_rule($_[0]);
$conf->[$_[0]->{'index'}] = $_[0];
$conf->[$_[1]->{'index'}] = $_[1];
}

sub config_for_rule
{
return $_[0]->{'type'} eq 'ipnat' ? &get_ipnat_config($_[0]->{'file'})
				  : &get_config($_[0]->{'file'});
}

# save_config(&rules, [file], type)
# Write out the entire config file
sub save_config
{
local $file = $_[1] || $_[0]->[0]->{'file'} ||
	      ($_[2] eq "ipnat" ? $config{'ipnat_conf'} : $config{'ipf_conf'});
&open_tempfile(FILE, ">$file");
local $r;
local $idx = 0;
local $lnum = 0;
foreach $r (@{$_[0]}) {
	$r->{'file'} = $file;
	$r->{'index'} = $idx++;
	$r->{'line'} = $lnum;
	local @lines = &rule_lines($r);
	$lnum += scalar(@lines);
	$r->{'eline'} = $lnum - 1;
	&print_tempfile(FILE, map { "$_\n" } &rule_lines($r));
	}
&close_tempfile(FILE);
if ($_[2] eq "ipnat") {
	$get_ipnat_config_cache{$file} = $_[0];
	}
else {
	$get_config_cache{$file} = $_[0];
	}
}

# rule_lines(&rule)
# Returns the lines of text that make up a rule
sub rule_lines
{
local ($rule) = @_;
local @rv = map { "# $_" } split(/\n/, $rule->{'cmt'});
local @w;
push(@w, "#") if (!$_[0]->{'active'});

if ($rule->{'type'} ne 'ipnat') {
	# Standard firewall rule
	# Add insert prefix
	push(@w, "\@", $rule->{'insert'}) if ($rule->{'insert'} ne "");

	# Add action and args
	push(@w, $rule->{'action'});
	if ($rule->{'action'} eq "block") {
		# Add block action options
		if ($rule->{'block-return'} eq "rst") {
			push(@w, "return-rst");
			}
		elsif ($rule->{'block-return'} ne "") {
			# XXX may be wrong
			push(@w, $rule->{'block-return-dest'} ? "return-icmp-as-dest"
							      : "return-icmp");
			push(@w, "(", $rule->{'block-return'}, ")");
			}
		}
	elsif ($rule->{'action'} eq "log") {
		# Add log action options
		&print_log("log");
		}
	elsif ($rule->{'action'} eq "skip") {
		push(@w, $rule->{'skip'});
		}
	elsif ($rule->{'action'} eq "call") {
		push(@w, "now") if ($rule->{'call-now'});
		push(@w, $rule->{'call'});
		}

	# Add in or out
	push(@w, $rule->{'dir'});

	# Add options
	if ($rule->{'olog'}) {
		push(@w, "log");
		&print_log("olog");
		}
	if ($rule->{'tag'} ne "") {
		push(@w, "tag", $rule->{'tag'});
		}
	if ($rule->{'quick'}) {
		push(@w, "quick");
		}
	if ($rule->{'on'} ne "") {
		push(@w, "on", $rule->{'on'});
		}
	if ($rule->{'dup-to'} ne "") {
		push(@w, "dup-to", $rule->{'dup-to'});
		}
	if ($rule->{'fastroute'} ne "") {
		push(@w, "fastroute", $rule->{'fastroute'});
		if ($rule->{'fastroute-ip'} ne "") {
			push(@w, ":", $rule->{'fastroute-ip'});
			}
		}
	if ($rule->{'reply-to'} ne "") {
		push(@w, "reply-to", $rule->{'reply-to'});
		if ($rule->{'reply-to-ip'} ne "") {
			push(@w, ":", $rule->{'reply-to-ip'});
			}
		}

	# Add TOS
	if ($rule->{'tos'} ne "") {
		push(@w, "tos", $rule->{'tos'});
		}

	# Add TTL
	if ($rule->{'ttl'} ne "") {
		push(@w, "ttl", $rule->{'ttl'});
		}

	# Add protocol
	if ($rule->{'proto'} ne "") {
		push(@w, "proto", $rule->{'proto'});
		}

	# Add to/from section
	if ($rule->{'all'}) {
		push(@w, "all");
		}
	else {
		push(@w, "from");
		&print_object("from");
		push(@w, "to");
		&print_object("to");
		}

	# Add IP options
	if ($rule->{'flags1'} ne "") {
		push(@w, "flags", $rule->{'flags1'});
		if ($rule->{'flags2'} ne "") {
			push(@w, "/", $rule->{'flags2'});
			}
		}
	if ($rule->{'with'}) {
		push(@w, "with", @{$rule->{'with'}});
		}
	if ($rule->{'icmp-type'} ne "") {
		push(@w, "icmp-type", $rule->{'icmp-type'});
		if ($rule->{'icmp-type-code'} ne "") {
			push(@w, "code", $rule->{'icmp-type-code'});
			}
		}
	if ($rule->{'keep'} ne "") {
		push(@w, "keep", $rule->{'keep'});
		}

	# Add group section
	if ($rule->{'head'} ne "") {
		push(@w, "head", $rule->{'head'});
		}
	if ($rule->{'group'} ne "") {
		push(@w, "group", $rule->{'group'});
		}
	}
else {
	# A NAT rule
	push(@w, $rule->{'action'});
	push(@w, $rule->{'iface'});
	if ($rule->{'action'} ne 'rdr') {
		# Mapping rule .. add the source
		if ($rule->{'from'}) {
			push(@w, "from");
			&print_object("from");
			push(@w, "to");
			&print_object("fromto");
			}
		else {
			&print_ipmask("from");
			}

		push(@w, "->");

		# Destination address
		if ($rule->{'tostart'}) {
			push(@w, "range", $rule->{'tostart'}, "-",
					  $rule->{'toend'});
			}
		else {
			&print_ipmask("to");
			}

		# Port mapping
		if ($rule->{'portmap'}) {
			push(@w, "portmap", $rule->{'portmap'});
			push(@w, $rule->{'portauto'} ? "auto" :
				   $rule->{'portmapfrom'}.":".
				   $rule->{'portmapto'});
			}

		# Proxy mapping
		if ($rule->{'proxyport'}) {
			&print_proxy("proxy");
			}

		# Add options
		if ($rule->{'proto'}) {
			push(@w, $rule->{'proto'});
			}
		if ($rule->{'frag'}) {
			push(@w, "frag");
			}
		if ($rule->{'age1'}) {
			push(@w, "age", $rule->{'age1'});
			if ($rule->{'age2'}) {
				push(@w, "/", $rule->{'age2'});
				}
			}
		if ($rule->{'mssclamp'}) {
			push(@w, "mssclamp", $rule->{'mssclamp'});
			}
		if ($rule->{'oproxyport'}) {
			&print_proxy("oproxy");
			}
		}
	else {
		# Redirect rule .. add source
		&print_ipmask("from");

		# Add destination ports
		push(@w, "port");
		push(@w, $rule->{'dport1'});
		if ($rule->{'dport2'}) {
			push(@w, "-", $rule->{'dport2'});
			}

		push(@w, "->");

		# Add destination IPs
		push(@w, join(" , ", @{$rule->{'rdrip'}}));

		# Add destination port and protocol
		push(@w, "port", $rule->{'rdrport'}, $rule->{'rdrproto'});

		# Add options
		if ($rule->{'round-robin'}) {
			push(@w, "round-robin");
			}
		if ($rule->{'frag'}) {
			push(@w, "frag");
			}
		if ($rule->{'age1'}) {
			push(@w, "age", $rule->{'age1'});
			if ($rule->{'age2'}) {
				push(@w, "/", $rule->{'age2'});
				}
			}
		if ($rule->{'mssclamp'}) {
			push(@w, "mssclamp", $rule->{'mssclamp'});
			}
		if ($rule->{'proxy'}) {
			push(@w, "proxy", $rule->{'proxy'});
			}
		}
	}

push(@rv, join(" ", @w));
return @rv;
}

# print_log(prefix)
sub print_log
{
local $pfx = $_[0];
push(@w, "body") if ($rule->{$pfx.'-body'});
push(@w, "first") if ($rule->{$pfx.'-first'});
push(@w, "or-block") if ($rule->{$pfx.'-or-block'});
push(@w, "level", $rule->{$pfx.'-level'}) if($rule->{$pfx.'-level'} ne "");
}

# print_object(dir)
sub print_object
{
local $dir = $_[0];
if ($rule->{$dir."-any"}) {
	push(@w, "any");
	}
elsif ($rule->{$dir."-thishost"}) {
	push(@w, "<thishost>");
	}
elsif ($rule->{$dir."-numhost"}) {
	push(@w, $rule->{$dir."-numhost"}."/".$rule->{$dir."-nummask"});
	}
else {
	push(@w, $rule->{$dir."-host"});
	if ($rule->{$dir."-mask"} ne "") {
		push(@w, "mask", $rule->{$dir."-mask"});
		}
	}

if ($rule->{$dir."-port-comp"}) {
	push(@w, "port", $rule->{$dir.'-port-comp'},
			 $rule->{$dir.'-port-num'});
	}
elsif ($rule->{$dir."-port-range"}) {
	push(@w, "port", $rule->{$dir.'-port-start'},
			 $rule->{$dir.'-port-range'},
			 $rule->{$dir.'-port-end'});
	}
}

# get_ipnat_config([file])
# Returns an array reference of ipnat rules
sub get_ipnat_config
{
local $file = $_[0] || $config{'ipnat_conf'};
return $get_ipnat_config_cache{$file} if ($get_ipnat_config_cache{$file});
open(FILE, $file);
while(<FILE>) {
	# Read each line, splitting into words
	s/\r|\n//g;
	if (/^\s*(#*)\s*((map-block|map|bimap|mapit|rdr).*)$/) {
		# A NAT rule, perhaps commented
		local $nocmt = $2;
		local @w = split(/\s+/, $nocmt);
		local @cmts = split(/\n/, $cmt);
		local $rule = { 'index' => scalar(@rv),
				'type' => 'ipnat',
				'line' => $lnum-scalar(@cmts),
				'eline' => $lnum,
				'file' => $file,
				'text' => $_,
				'cmt' => $cmt,
				'active' => !$1 };
		$cmt = undef;

		# Parse action
		$rule->{'action'} = shift(@w);

		if ($rule->{'action'} eq 'map' ||
		    $rule->{'action'} eq 'bimap' ||
		    $rule->{'action'} eq 'map-block') {
			# Parse interface
			$rule->{'iface'} = shift(@w);

			if ($w[0] eq "from") {
				# A full from XXX to YYY block
				shift(@w);	# skip 'from'
				$rule->{'from'} = 1;
				&parse_object("from");
				shift(@w);	# skip 'to'
				&parse_object("fromto");
				}
			else {
				# IP and netmask only
				&parse_ipmask("from");
				}

			local $arrow = shift(@w);
			$arrow eq "->" ||
				&error("error parsing IPNAT line $_ at ".
				       "$arrow line $lnum");

			if ($w[0] eq "range") {
				# A destination IP range
				shift(@w);	# skip 'range'
				$rule->{'tostart'} = shift(@w);
				if ($rule->{'tostart'} =~ /^(\S+)\-(\S+)$/) {
					$rule->{'tostart'} = $1;
					$rule->{'toend'} = $2;
					}
				else {
					shift(@w);	# skip '-'
					$rule->{'toend'} = shift(@w);
					}
				}
			else {
				# Destination IP and netmask only
				&parse_ipmask("to");
				}

			if ($w[0] eq "portmap") {
				# Parse port mapping
				shift(@w);	# skip 'portmap'
				$rule->{'portmap'} = shift(@w);
				if ($w[0] eq "auto") {
					shift(@w);	# skip 'auto'
					$rule->{'portauto'} = 1;
					}
				else {
					($rule->{'portmapfrom'},
				         $rule->{'portmapto'}) =
						split(/:/, shift(@w));
					}
				}

			if ($w[0] eq "proxy") {
				# Parse proxy
				&parse_proxy("proxy");
				}

			# Parse options
			if ($w[0] eq "tcp/udp" ||
			    getprotobyname($w[0]) || $w[0] =~ /^\d+$/) {
				$rule->{'proto'} = shift(@w);
				}
			if ($w[0] eq "frag") {
				$rule->{'frag'} = shift(@w);
				}
			if ($w[0] eq "age") {
				shift(@w);	# skip 'age'
				$rule->{'age1'} = shift(@w);
				if ($w[0] eq "/") {
					shift(@w);	# skip '/'
					$rule->{'age2'} = shift(@w);
					}
				}
			if ($w[0] eq "mssclamp") {
				shift(@w);	# skip 'mssclamp'
				$rule->{'mssclamp'} = shift(@w);
				}
			if ($w[0] eq "proxy") {
				# Parse proxy option
				&parse_proxy("oproxy");
				}
			}
		elsif ($rule->{'action'} eq 'rdr') {
			# Parse redirect
			$rule->{'iface'} = shift(@w);

			# Parse IP and netmask
			&parse_ipmask("from");

			# Parse destination ports
			local $ports = shift(@w);
			$ports eq "port" ||
				&error("error parsing IPNAT line $_ at ".
				       "$ports line $lnum");
			$rule->{'dport1'} = shift(@w);
			if ($w[0] eq "-") {
				shift(@w);	# skip '-'
				$rule->{'dport2'} = shift(@w);
				}

			local $arrow = shift(@w);
			$arrow eq "->" ||
				&error("error parsing IPNAT line $_ at ".
				       "$arrow line $lnum");

			# Parse destination IPs
			$rule->{'rdrip'} = [ shift(@w) ];
			while($w[0] eq ",") {
				shift(@w);	# skip ,
				push(@{$rule->{'rdrip'}}, shift(@w));
				}

			# Parse destination port
			shift(@w);	# skip 'port'
			$rule->{'rdrport'} = shift(@w);

			# Parse protocol
			$rule->{'rdrproto'} = shift(@w);

			# Parse other options
			if ($w[0] eq "round-robin") {
				$rule->{'round-robin'} = shift(@w);
				}
			if ($w[0] eq "frag") {
				$rule->{'frag'} = shift(@w);
				}
			if ($w[0] eq "age") {
				shift(@w);	# skip 'age'
				$rule->{'age1'} = shift(@w);
				if ($w[0] eq "/") {
					shift(@w);	# skip '/'
					$rule->{'age2'} = shift(@w);
					}
				}
			if ($w[0] eq "mssclamp") {
				shift(@w);	# skip 'mssclamp'
				$rule->{'mssclamp'} = shift(@w);
				}
			if ($w[0] eq "proxy") {
				shift(@w);	# skip 'proxy'
				$rule->{'proxy'} = shift(@w);
				}
			}
		push(@rv, $rule);
		}
	elsif (/^\s*#\s*(.*)$/) {
		# A comment line
		$cmt .= "\n" if ($cmt);
		$cmt .= $1;
		}
	nextline:
	$lnum++;
	}
close(FILE);
$get_ipnat_config_cache{$file} = \@rv;
return $get_ipnat_config_cache{$file};
}

# parse_ipmask(prefix)
sub parse_ipmask
{
local ($pfx) = @_;
local $ip = shift(@w);
if ($ip =~ /^(\S+)\/(\S+)$/) {
	$rule->{$pfx."ip"} = $1;
	$rule->{$pfx."mask"} = $2;
	}
else {
	$rule->{$pfx."ip"} = $ip;
	shift(@w);	# skip '/' or 'netmask'
	$rule->{$pfx."mask"} = shift(@w);
	}
}

# print_ipmask(prefix)
sub print_ipmask
{
local ($pfx) = @_;
push(@w, $rule->{$pfx."ip"}."/".$rule->{$pfx."mask"});
}

# parse_proxy(prefix)
sub parse_proxy
{
local ($pfx) = @_;
shift(@w);	# skip 'proxy'
shift(@w);	# skip 'port'
$rule->{$pfx.'port'} = shift(@w);
$rule->{$pfx.'name'} = shift(@w);
if ($rule->{$pfx.'name'} =~ /^(\S+)\/(\S+)$/) {
	$rule->{$pfx.'name'} = $1;
	$rule->{$pfx.'proto'} = $2;
	}
else {
	shift(@w);	# skip '/'
	$rule->{$pfx.'proto'} = shift(@w);
	}
}

# print_proxy(prefix)
sub print_proxy
{
local ($pfx) = @_;
push(@w, "proxy", "port", $rule->{$pfx.'port'},
         $rule->{$pfx.'name'}."/".$rule->{$pfx.'proto'});
}

# list_protocols()
# Returns a list of IP protocols
sub list_protocols
{
local @stdprotos = ( 'tcp', 'udp', 'icmp' );
local @otherprotos;
open(PROTOS, "/etc/protocols");
while(<PROTOS>) {
	s/\r|\n//g;
	s/#.*$//;
	push(@otherprotos, $1) if (/^(\S+)\s+(\d+)/);
	}
close(PROTOS);
@otherprotos = sort { lc($a) cmp lc($b) } @otherprotos;
return &unique(@stdprotos, @otherprotos);
}

# apply_configuration()
# Activates the IPfilter configuration, and returns undef on success or an
# error message on failure.
sub apply_configuration
{
local $out;
if ($config{'apply_cmd'} && !$config{'smf'}) {
	$out = &backquote_logged("$config{'apply_cmd'} 2>&1 </dev/null");
	}
else {
	&system_logged("$config{'ipf'} -F a -f $config{'ipf_conf'} >/dev/null 2>&1");
	$out = &backquote_logged("$config{'ipf'} -f $config{'ipf_conf'} 2>&1 </dev/null");
	if (-r $config{'ipnat_conf'} && !$?) {
		&system_logged("$config{'ipnat'} -C -F -f $config{'ipnat_conf'} >/dev/null 2>&1");
		$out = &backquote_logged("$config{'ipnat'} -f $config{'ipnat_conf'} 2>&1 </dev/null");
		}
	}
return $? || $out =~ /error|failed|unknown/i ? "<pre>$out</pre>" : undef;
}

# check_firewall_init()
# Returns 2 if started at boot, 1 or 0 if not
sub check_firewall_init
{
if ($config{'smf'}) {
	# Look for SMF service
	&foreign_require("smf", "smf-lib.pl");
	local $state = &smf::svc_get_state_cmd($config{'smf'});
	return $state eq 'online' ? 2 :
	       $state eq 'disabled' || $state eq 'offline' ||
	        $state eq 'maintenance' ? 1 : 0;
	}
elsif ($gconfig{'os_type'} eq 'freebsd') {
	# Check for built-in rc config
	&foreign_require("init");
	local @rc = &init::get_rc_conf();
	local ($rc) = grep { $_->{'name'} eq 'ipfilter_enable' &&
			     $_->{'value'} eq 'YES' } @rc;
	return $rc ? 2 : 1;
	}
else {
	# Look at init script
	&foreign_require("init");
	return &init::action_status($init_script);
	}
}

# create_firewall_init()
# Create (if necessary) the ipfilter init script, and enable it
sub create_firewall_init
{
if ($config{'smf'}) {
	# Enable SMF service
	&foreign_require("smf", "smf-lib.pl");
	local $atboot = &check_firewall_init();
	$atboot || &error(&text('boot_esmf', "<tt>$config{'smf'}</tt>"));
	if ($atboot != 2) {
		&smf::svc_state_cmd($smf::text{'state_enable'},
				    [ $config{'smf'} ]);
		}
	}
elsif ($gconfig{'os_type'} eq 'freebsd') {
	# Use built-in config
	&foreign_require("init");
	&init::save_rc_conf("ipfilter_enable", "YES");
	&init::save_rc_conf("ipfilter_rules", $config{'ipf_conf'});
	my $natrules = &get_ipnat_config();
	if (@$natrules) {
		&init::save_rc_conf("ipnat_enable", "YES");
		&init::save_rc_conf("ipnat_rules", $config{'ipnat_conf'});
		}
	}
else {
	# Create or enable init script
	local $ipf = &has_command($config{'ipf'});
	local $ipfstat = &has_command($config{'ipfstat'});
	local $start = "$ipf -F a\n".
		       "$ipf -f $config{'ipf_conf'}";
	local $stop = "$ipf -F a".
	&foreign_require("init");
	&init::enable_at_boot($init_script, "Activate IPfilter firewall",
			      $start, $stop);
	}
}

# delete_firewall_init()
# Turn off the firewall at boot time
sub delete_firewall_init
{
if ($config{'smf'}) {
	# Disable SMF service
	&foreign_require("smf", "smf-lib.pl");
	local $atboot = &check_firewall_init();
	$atboot || &error(&text('boot_esmf', "<tt>$config{'smf'}</tt>"));
	if ($atboot == 2) {
		&smf::svc_state_cmd($smf::text{'state_disable'},
				    [ $config{'smf'} ]);
		}
	}
elsif ($gconfig{'os_type'} eq 'freebsd') {
	# Use built-in config
	&foreign_require("init");
	&init::save_rc_conf("ipfilter_enable", "NO");
	&init::save_rc_conf("ipnat_enable", "NO");
	}
else {
	# Disable init script
	&foreign_require("init", "init-lib.pl");
	&init::disable_at_boot($init_script);
	}
}

# unapply_configuration()
# Replace the IPfilter configuration file with active rules
sub unapply_configuration
{
local $inrules = `$config{'ipfstat'} -i 2>/dev/null </dev/null`;
return $text{'unapply_ein'} if ($?);
local $outrules = `$config{'ipfstat'} -o 2>/dev/null </dev/null`;
return $text{'unapply_eout'} if ($?);

&open_lock_tempfile(OUT, ">$config{'ipf_conf'}");
&print_tempfile(OUT, $inrules);
&print_tempfile(OUT, $outrules);
&close_tempfile(OUT);

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
foreach $s (&list_cluster_servers()) {
	&remote_foreign_require($s, "ipfilter", "ipfilter-lib.pl");
	local $iconfig = &remote_foreign_config($s, "ipfilter");
	&remote_write($s, $config{'ipf_conf'}, $iconfig->{'ipf_conf'});
	if ($iconfig{'ipnat_conf'} && -r $config{'ipnat_conf'} &&
	    $config{'cluster_nat'}) {
		&remote_write($s, $config{'ipnat_conf'},
				  $iconfig->{'ipnat_conf'});
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
	&remote_foreign_require($s, "ipfilter", "ipfilter-lib.pl");
	local $err = &remote_foreign_call($s, "ipfilter", "apply_configuration");
	if ($err) {
		return &text('apply_remote', $s->{'host'}, $err);
		}
	}
return undef;
}

# object_input(rule, prefix, [no-thishost])
# Returns HTML for selecting an address and HTML for selecting a port
sub object_input
{
local ($rule, $f, $nothis) = @_;

# Address part
local $ft;
$ft .= &ui_oneradio($f, "any", $text{'edit_any'},
		    $rule->{$f."-any"} || $rule->{'all'})."\n";
if ($nothis) {
	$ft .= "<br>\n";
	}
else {
	$ft .= &ui_oneradio($f, "thishost", $text{'edit_thishost'},
			    $rule->{$f."-thishost"})."<br>\n";
	}

$ft .= &ui_oneradio($f, "host", $text{'edit_host'},
		    $rule->{$f."-host"})."\n";
$ft .= &ui_textbox($f."_host", $rule->{$f."-host"}, 20)."\n";
$ft .= "$text{'edit_mask'}\n";
$ft .= &ui_textbox($f."_mask", $rule->{$f."-mask"}, 13)."<br>\n";

$ft .= &ui_oneradio($f, "numhost", $text{'edit_host'},
		    $rule->{$f."-numhost"}),"\n";
$ft .= &ui_textbox($f."_numhost", $rule->{$f."-numhost"}, 20)."\n";
$ft .= "$text{'edit_nummask'}\n";
$ft .= &ui_textbox($f."_nummask", $rule->{$f."-nummask"}, 6)."\n".
       "$text{'edit_opt'}<br>\n";

# Ports part
local $pt;

$pt .= &ui_oneradio($f."_port", "any", $text{'edit_anyport'},
		    !$rule->{$f."-port-comp"} &&
		    !$rule->{$f."-port-range"})."\n";
$pt .= &ui_oneradio($f."_port", "comp",
    &text('edit_portcomp',
	  &ui_select($f."_portcomp", $rule->{$f."-port-comp"},
		     [ map { [ $_ ] } @compare_ops ],
		     0, 0, $rule->{$f."-port-comp"} ? 1 : 0),
	  &ui_textbox($f."_portnum", $rule->{$f."-port-num"}, 6)),
    $rule->{$f."-port-comp"})."<br>\n";
$pt .= &ui_oneradio($f."_port", "range",
    &text('edit_portrange',
	  &ui_textbox($f."_portstart", $rule->{$f."-port-start"}, 6),
	  &ui_textbox($f."_portend", $rule->{$f."-port-end"}, 6)),
    $rule->{$f."-port-range"} eq '><')."<br>\n";
$pt .= &ui_oneradio($f."_port", "rangenot",
    &text('edit_portrangenot',
	  &ui_textbox($f."_portstartnot", $rule->{$f."-port-start"}, 6),
	  &ui_textbox($f."_portendnot", $rule->{$f."-port-end"}, 6)),
    $rule->{$f."-port-range"} eq '<>')."<br>\n";

return ($ft, $pt);
}

# parse_object_input(rule, prefix)
sub parse_object_input
{
local ($rule, $f) = @_;
delete($rule->{$f."-any"});
delete($rule->{$f."-thishost"});
delete($rule->{$f."-host"});
delete($rule->{$f."-numhost"});
if ($in{$f} eq "any") {
	$rule->{$f."-any"} = 1;
	}
elsif ($in{$f} eq "thishost") {
	$rule->{$f."-thishost"} = 1;
	}
elsif ($in{$f} eq "host") {
	&to_ipaddress($in{$f."_host"}) ||
		&error($text{'save_ehost'.$f});
	$rule->{$f."-host"} = $in{$f."_host"};
	&check_ipaddress($in{$f."_mask"}) ||
		&error($text{'save_emask'.$f});
	$rule->{$f."-mask"} = $in{$f."_mask"};
	}
elsif ($in{$f} eq "numhost") {
	&to_ipaddress($in{$f."_numhost"}) ||
		&error($text{'save_ehost'.$f});
	$rule->{$f."-numhost"} = $in{$f."_numhost"};
	$in{$f."_nummask"} = "32" if ($in{$f."_nummask"} eq "");
	$in{$f."_nummask"} =~ /^\d+$/ &&
	    $in{$f."_nummask"} <= 32 ||
		&error($text{'save_enummask'.$f});
	$rule->{$f."-nummask"} = $in{$f."_nummask"};
	}

# Parse port section
delete($rule->{$f."-port-comp"});
delete($rule->{$f."-port-range"});

return ($ft, $pt);
}

# parse_object_input(rule, prefix)
sub parse_object_input
{
local ($rule, $f) = @_;
delete($rule->{$f."-any"});
delete($rule->{$f."-thishost"});
delete($rule->{$f."-host"});
delete($rule->{$f."-numhost"});
if ($in{$f} eq "any") {
	$rule->{$f."-any"} = 1;
	}
elsif ($in{$f} eq "thishost") {
	$rule->{$f."-thishost"} = 1;
	}
elsif ($in{$f} eq "host") {
	&to_ipaddress($in{$f."_host"}) ||
		&error($text{'save_ehost'.$f});
	$rule->{$f."-host"} = $in{$f."_host"};
	&check_ipaddress($in{$f."_mask"}) ||
		&error($text{'save_emask'.$f});
	$rule->{$f."-mask"} = $in{$f."_mask"};
	}
elsif ($in{$f} eq "numhost") {
	&to_ipaddress($in{$f."_numhost"}) ||
		&error($text{'save_ehost'.$f});
	$rule->{$f."-numhost"} = $in{$f."_numhost"};
	$in{$f."_nummask"} = "32" if ($in{$f."_nummask"} eq "");
	$in{$f."_nummask"} =~ /^\d+$/ &&
	    $in{$f."_nummask"} <= 32 ||
		&error($text{'save_enummask'.$f});
	$rule->{$f."-nummask"} = $in{$f."_nummask"};
	}

# Parse port section
delete($rule->{$f."-port-comp"});
delete($rule->{$f."-port-range"});
if ($in{$f."_port"} eq "comp") {
	&valid_port($in{$f."_portnum"}) ||
		&error($text{'save_eportnum'.$f});
	$rule->{$f."-port-num"} = $in{$f."_portnum"};
	$rule->{$f."-port-comp"} = $in{$f."_portcomp"};
	}
elsif ($in{$f."_port"} eq "range") {
	&valid_port($in{$f."_portstart"}) ||
		&error($text{'save_eportstart'.$f});
	&valid_port($in{$f."_portend"}) ||
		&error($text{'save_eportend'.$f});
	$rule->{$f."-port-range"} = "><";
	$rule->{$f."-port-start"} = $in{$f."_portstart"};
	$rule->{$f."-port-end"} = $in{$f."_portend"};
	}
elsif ($in{$f."_port"} eq "rangenot") {
	&valid_port($in{$f."_portstartnot"}) ||
		&error($text{'save_eportstart'.$f});
	&valid_port($in{$f."_portendnot"}) ||
		&error($text{'save_eportend'.$f});
	$rule->{$f."-port-range"} = "<>";
	$rule->{$f."-port-start"} = $in{$f."_portstartnot"};
	$rule->{$f."-port-end"} = $in{$f."_portendnot"};
	}
}

# protocol_input(name, value, add-any, add-tcp-udp)
sub protocol_input
{
local ($name, $value, $any, $tcpudp) = @_;
return &ui_select($name, $value,
	       [ $any ? ( [ "", $text{'edit_protoany'} ] ) : ( ),
		 $tcpudp ? ( [ "tcp/udp", $text{'edit_prototcpudp'} ] ) : ( ),
		 map { [ $_, uc($_) ] } &list_protocols() ],
	       0, 0, $value ? 1 : 0);
}

# valid_port(name|number)
# Returns 1 if give a valid port number or TCP or UDP name
sub valid_port
{
local $n = $_[0];
return getservbyname($n, "tcp") ||
       getservbyname($n, "udp") ||
       ($n =~ /^\d+$/ && $n > 0 && $n < 65536);
}

sub valid_hexdec
{
return $_[0] =~ /^\d+$/ || $_[0] =~ /^0x([0-9a-f]+)$/;
}

1;

