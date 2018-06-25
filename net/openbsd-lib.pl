# freebsd-lib.pl
# Networking functions for FreeBSD

# active_interfaces()
# Returns a list of currently ifconfig'd interfaces
sub active_interfaces
  {
      local(@rv, @lines, $l);
      &open_execute_command(IFC, "ifconfig -A", 1, 1);
      while(<IFC>) {
	  s/\r|\n//g;
	  if (/^\S+:/) { push(@lines, $_); }
	  else { $lines[$#lines] .= $_; }
      }
      close(IFC);
      foreach $l (@lines) {
	  local %ifc;
	  $l =~ /^([^:\s]+):/;
	  $ifc{'name'} = $ifc{'fullname'} = $1;
	  if ($l =~ /^(\S+):(\d+):\s/) { $ifc{'virtual'} = $2; }
	  if ($l =~ s/inet\s+(\S+)\s+netmask\s+(\S+)\s+broadcast\s+(\S+)//) {
	      $ifc{'address'} = $1;
	      $ifc{'netmask'} = &parse_hex($2);
	      $ifc{'broadcast'} = $3;
	  }
	  elsif ($l =~ s/inet\s+(\S+)\s+netmask\s+(\S+)//) {
	      $ifc{'address'} = $1;
	      $ifc{'netmask'} = &parse_hex($2);
	  }
	  else { next; }
	  if ($l =~ /ether\s+(\S+)/) { $ifc{'ether'} = $1; }
	  if ($l =~ /mtu\s+(\S+)/) { $ifc{'mtu'} = $1; }
	  $ifc{'up'}++ if ($l =~ /\<UP/);
	  $ifc{'edit'} = &iface_type($ifc{'name'}) =~ /ethernet|loopback/i;
	  $ifc{'index'} = scalar(@rv);
	  if ($ifc{'ether'}) {
	      $ifc{'ether'} = join(":", map { sprintf "%2.2d", $_ }
				   split(/:/, $ifc{'ether'}));
	  }
	  push(@rv, \%ifc);
	  
	  # Add aliases as virtual interfaces
	  local $v = 0;
	  while($l =~ s/inet\s+(\S+)\s+netmask\s+(\S+)\s+broadcast\s+(\S+)//) {
	      local %vifc = %ifc;
	      $vifc{'address'} = $1;
	      $vifc{'netmask'} = &parse_hex($2);
	      $vifc{'broadcast'} = $3;
	      $vifc{'up'} = 1;
	      $vifc{'edit'} = $ifc{'edit'};
	      $vifc{'virtual'} = $v++;
	      $vifc{'fullname'} = $vifc{'name'}.':'.$vifc{'virtual'};
	      $vifc{'index'} = scalar(@rv);
	      push(@rv, \%vifc);
	  }
      }
      return @rv;
  }

# activate_interface(&details)
# Create or modify an interface
sub activate_interface
  {
      local %act;
      map { $act{$_->{'fullname'}} = $_ } &active_interfaces();
      local $old = $act{$_[0]->{'fullname'}};
      $act{$_[0]->{'fullname'}} = $_[0];
      &interface_sync(\%act, $_[0]->{'name'});
  }

# deactivate_interface(&details)
# Deactive an interface
sub deactivate_interface
  {
      local %act;
      local @act = &active_interfaces();
      if ($_[0]->{'virtual'} eq '') {
	  @act = grep { $_->{'name'} ne $_[0]->{'name'} } @act;
      }
      else {
	  @act = grep { $_->{'fullname'} ne $_[0]->{'fullname'} } @act;
      }
      map { $act{$_->{'fullname'}} = $_ } @act;
      &interface_sync(\%act, $_[0]->{'name'});
  }

# interface_sync(interfaces, name)
sub interface_sync
  {
      while(&backquote_command("ifconfig $_[1]") =~ /\s+inet\s+/) {
	  &system_logged("ifconfig $_[1] delete >/dev/null 2>&1");
      }
      foreach $a (sort { $a->{'fullname'} cmp $b->{'fullname'} }
		  grep { $_->{'name'} eq $_[1] } values(%{$_[0]})) {
	  local $cmd = "ifconfig $a->{'name'}";
	  if ($a->{'virtual'} ne '') {
	      $cmd .= " alias $a->{'address'}";
	  }
	  else {
	      $cmd .= " $a->{'address'}";
	  }
	  if ($a->{'netmask'}) { $cmd .= " netmask $a->{'netmask'}"; }
	  if ($a->{'broadcast'}) { $cmd .= " broadcast $a->{'broadcast'}"; }
	  if ($a->{'mtu'}) { $cmd .= " mtu $a->{'mtu'}"; }
	  $msg .= "running $cmd<br>\n";
	  local $out = &backquote_logged("$cmd 2>&1");
	  if ($? && $out !~ /file exists/i) {
	      &error($out);
	  }
	  if ($a->{'virtual'} eq '') {
	      if ($a->{'up'}) { $out = &backquote_command("ifconfig $a->{'name'} up 2>&1"); }
	      else { $out = &backquote_logged("ifconfig $a->{'name'} down 2>&1"); }
	      &error($out) if ($?);
	  }
      }
  }


# boot_interfaces()
# Returns a list of interfaces brought up at boot time
sub boot_interfaces 
  {
      local @rv;
      local @if_list = split(" ",
	&backquote_command("echo -n /etc/hostname.*[!~]"));
      
      if ( $if_list[0] eq "/etc/hostname.*[!~]" )
	{ return @rv; }
      
      foreach $r (@if_list) {
	  local $if;
	  local $alias_cnt = 0;
	  
	  ($if = $r) =~ s/\/etc\/hostname\.//;
	  
	  &open_readfile( IF_FILE, $r)
	    or die "Could not open: $r";
	  
	  while(<IF_FILE>) {
	      local %ifc;
	      
	      if( ! /^inet .*|^dhcp/ )
		{ next; }
	      
	      if( /^dhcp/ ) {
		%ifc = ( 'name' => $if,
			 'fullname' => $if,
			 'dhcp' => 1 );
	      }	
	      elsif( /alias/ ) {
		  $_ =~ s/alias//;
		  # Virtual interface
		  %ifc = ( 'name' => $if,
			   'virtual' => $alias_cnt,
			   'fullname' => "$if:$alias_cnt" );
		  $alias_cnt++;
	      }
	      else {
		  # Non-virtual interface
		  %ifc = ( 'name' => $if,
			   'fullname' => $if );
	      }
	      
	      @_ = split;
	      
	      $ifc{'address'} = $_[1] if( $_[1] ne 'NONE' );
	      $ifc{'netmask'} = $_[2] if( $_[2] ne 'NONE' );
	      $ifc{'broadcast'} = $_[3] if( $_[3] ne 'NONE' );
	      $ifc{'up'} = 1;
	      $ifc{'edit'} = 1;
	      $ifc{'index'} = scalar(@rv);
	      $ifc{'file'} = $r;
	      push(@rv, \%ifc);
	  }
	  close( IF_FILE );
      }
      return @rv;
  }

# save_interface(&details)
# Create or update a boot-time interface
sub save_interface 
{
    local ($str, $lines, $found = 0);
    local $if = $_[0]->{'name'};
    local $alias_nr = $_[0]->{'virtual'};
    
    &lock_file("/etc/hostname.$if");
    if ( $_[0]->{'dhcp'} ){ 
      &open_tempfile( IF_FILE, ">/etc/hostname.".$if );
      &print_tempfile(IF_FILE, "dhcp\n");
      &close_tempfile( IF_FILE );
      &unlock_file("/etc/hostname.$if");
      return;
    }

    if ( $alias_nr eq '' ) {
	$str = "inet ";
	$alias_nr = 0;
    }
    else {
	$str = "inet alias "; 
	$alias_nr += 1;
    }

    $str .= $_[0]->{'address'};
    $str .= " $_[0]->{'netmask'}" if ($_[0]->{'netmask'});
    $str .= " $_[0]->{'broadcast'}" if ($_[0]->{'broadcast'});

    $_ = &backquote_command("echo -n /etc/hostname.*");

    if( /hostname.$if/ ) {
	$lines = &read_file_lines( "/etc/hostname.".$if );
	foreach $l (@$lines) {
	    $_ = $l;
	    if( ! /^inet |^dhcp/ )
	      { next; }
	    if( $alias_nr == 0 ) {
		$l = $str;
		$found = 1;
		last;
	    }
	    if( ! /alias/ )
	      { next; }
	    if( $alias_nr == 1 ) {
		$l = $str;
		$found = 1;
		last;
	    }
	    $alias_nr--;
	}
	if( $found == 0 ) {
	    push @$lines, ($str);
	}
	&flush_file_lines();
    } 
    else {
	&open_tempfile( IF_FILE, ">/etc/hostname.".$if );
	&print_tempfile(IF_FILE, $str, "\n");
	&close_tempfile( IF_FILE );
    }
    &unlock_file("/etc/hostname.$if");

}

# delete_interface(&details)
# Delete a boot-time interface
sub delete_interface
{
    local ($cnt = 0, $lines, $found = 0);
    local $if = $_[0]->{'name'};
    local $addr = $_[0]->{'address'};
    
    $_ = &backquote_command("echo -n /etc/hostname.*");

    &lock_file("/etc/hostname.$if");
    if( /hostname.$if/ ) {
	$lines = &read_file_lines( "/etc/hostname.".$if );
	foreach $l (@$lines) {
	    $_ = $l;
	    $cnt++;
	    if ( /^\#/ )
	      { next; }
	    $found++;
	    if( ! /^inet / )
	      { next; }
	    if( /$addr/ )
	      { splice @$lines, $cnt-1, 1; }
	}
	&flush_file_lines();
	# check if we deleted the only entry in the file
	# if so delete the file (otherwise dhcp will be used for the interface)
	if( $found == 1 ) {
	    &unlink_logged("/etc/hostname.".$if);
	}
    } 
    &unlock_file("/etc/hostname.$if");
}

# iface_type(name)
# Returns a human-readable interface type name
sub iface_type
  {
      return	$_[0] =~ /^tun/ ? "Loopback tunnel" :
	$_[0] =~ /^sl/ ? "SLIP" :
	  $_[0] =~ /^ppp/ ? "PPP" :
	    $_[0] =~ /^lo/ ? "Loopback" :
	      $_[0] =~ /^ar/ ? "Arnet" :
		$_[0] =~ /^(aue|cue|kue)/ ? "USB ethernet" :
		  $_[0] =~ /^(sk|ti|wx)/ ? "Gigabit ethernet" :
		    $_[0] =~ /^(al|ax|be|mx|qe|qec|rl|sf|sis|ste|tx|wb)/ ? "Fast ethernet" :
		      $_[0] =~ /^(ae|cs|dc|de|ec|ed|eg|el|en|ep|es|ex|fxp|hme|ie|il|ix|iy|le|mc|ne|np|qn|sm|sn|tl|vr|vx|we|xe|xl|ze|zp)/ ? "Ethernet" : $text{'ifcs_unknown'};
  }

# iface_hardware(name)
# Does some interface have an editable hardware address
sub iface_hardware
  {
      return 0;
  }

# can_edit(what)
# Can some boot-time interface parameter be edited?
sub can_edit
  {
      return $_[0] =~ /netmask|broadcast|dhcp/;
  }

# valid_boot_address(address)
# Is some address valid for a bootup interface
sub valid_boot_address
  {
      return &check_ipaddress($_[0]);
  }

# get_dns_config()
# Returns a hashtable containing keys nameserver, domain, search & order
sub get_dns_config
  {
      local $dns;
      &open_readfile(RESOLV, "/etc/resolv.conf");
      while(<RESOLV>) {
	  s/\r|\n//g;
	  s/#.*$//g;		
	  if (/nameserver\s+(.*)/) {
	      push(@{$dns->{'nameserver'}}, split(/\s+/, $1));
	  }
	  elsif (/search\s+(.*)/) {
	      $dns->{'domain'} = [ split(/\s+/, $1) ];
	  }
	  elsif (/lookup\s+(.*)/) {
	      $dns->{'order'} = [ split(/\s+/, $1) ];
	  }
      }
      close(RESOLV);
      
      $dns->{'files'} = [ "/etc/resolv.conf" ];
      return $dns;
  }

# save_dns_config(&config)
# Writes out the resolv.conf file
sub save_dns_config
  {
      &lock_file("/etc/resolv.conf");
      &open_readfile(RESOLV, "/etc/resolv.conf");
      local @resolv = <RESOLV>;
      close(RESOLV);
      &open_tempfile(RESOLV, ">/etc/resolv.conf");
      foreach (@{$_[0]->{'nameserver'}}) {
	  &print_tempfile(RESOLV, "nameserver $_\n");
      }
      if ($_[0]->{'domain'}) {
	  &print_tempfile(RESOLV, "search ",join(" ", @{$_[0]->{'domain'}}),"\n");
      }
      foreach (@resolv) {
	  &print_tempfile(RESOLV, $_) if (!/^\s*(nameserver|search|lookup)\s+/);
      }
      &print_tempfile(RESOLV, "lookup ");
      foreach (@{$_[0]->{'order'}}) {
	  &print_tempfile(RESOLV, $_," ");
      }
      &print_tempfile(RESOLV, "\n");
      &close_tempfile(RESOLV);
      &unlock_file("/etc/resolv.conf");
      
  }

$max_dns_servers = 3;

# order_input(&dns)
# Returns HTML for selecting the name resolution order
sub order_input
{
return &common_order_input("order", $_[0]->{'order'},
	[ [ "file", "Hosts" ], [ "bind", "DNS" ], [ "yp", "NIS" ] ]);
}

# parse_order(&dns)
# Parses the form created by order_input()
sub parse_order
  {
      local($i, @order);
      for($i=0; defined($in{"order_$i"}); $i++) {
	  push(@order, $in{"order_$i"}) if ($in{"order_$i"});
      }
      $_[0]->{'order'} = \@order;
  }

# get_hostname()
sub get_hostname
{
local $hn = &read_file_contents("/etc/myname");
$hn =~ s/\r|\n//g;
if ($hn) {
	return $hn;
	}
return &get_system_hostname();
}

# save_hostname(name)
sub save_hostname
  {
      &system_logged("hostname $_[0] >/dev/null 2>&1");
      &open_lock_tempfile(MYNAME, ">/etc/myname");
      &print_tempfile(MYNAME, $_[0],"\n");
      &close_tempfile(MYNAME);
	undef(@main::get_system_hostname);      # clear cache
  }

sub set_line {
    local ($l, $lines, $found = 0);
    local $pat = $_[1];
    local $news = $_[2];

    $lines = read_file_lines($_[0]);
    foreach $l (@$lines) {
	$_ = $l;
	if( /$pat/ ) {
	    $found = 1;
	    $l = $news;
	}
    } 
    if( ! $found ) {
	push @$lines, ($news);
    }

    &flush_file_lines();
}

sub read_routing {
    $defr = '';
    &open_readfile(DEFR, "/etc/mygate");
    while(<DEFR>) {
	$defr .= $_;
    }
    close(DEFR);

    local %sysctl;
    read_file("/etc/sysctl.conf", \%sysctl);
    $gw = "$sysctl{'net.inet.ip.forwarding'}";
    $gw =~ s/\s*\#.*//; 
    $gw = "0" if( $gw eq '' );

    local %rc;
    read_file("/etc/rc.conf",\%rc);
    $rd = $rc{'routed_flags'};
    $rd =~ s/\s*\#.*//; 
    $rd = "NO" if( $rd eq '' );
}

sub routing_config_files
{
return ( "/etc/mygate", "/etc/sysctl.conf", "/etc/rc.conf" );
}

sub routing_input
{
&read_routing;

# Default router
print &ui_table_row($text{'routes_default'},
	&ui_opt_textbox("defr", $defr eq 'NO' ? '' : $defr, 20,
			$text{'routes_none'}));

# Act as router?
print &ui_table_row($text{'routes_forward'},
	&ui_radio("gw", $gw || 0, [ [ 1, $text{'yes'} ],
				    [ 0, $text{'no'} ] ]));

# Run route discovery
print &ui_table_row($text{'routes_routed'},
	&ui_radio("rd", $rd || '-q', [ [ '-q', $text{'yes'} ],
				       [ 'NO', $text{'no'} ] ]));
}

sub parse_routing
  {
      $in{'defr_def'} || &check_ipaddress($in{'defr'}) ||
	&error(&text('routes_edefault', $in{'defr'}));

      &read_routing;

      &lock_file("/etc/mygate");
      if ( $in{'defr_def'} && -f "/etc/mygate" ) {
	  &unlink_file("/etc/mygate");
      }
      else {
	  if( $in{'defr'} ne $defr ) {
		&open_tempfile(MYGATE, ">/etc/mygate");
		&print_tempfile(MYGATE, $in{'defr'},"\n");
		&close_tempfile(MYDATE);
	  }
      }
      &unlock_file("/etc/mygate");
      
      if( $in{'gw'} ne $gw ) {
	  &set_line( "/etc/sysctl.conf", "^net.inet.ip.forwarding", "net.inet.ip.forwarding=$in{'gw'}" );
      }

      if( $in{'rd'} ne $rd ) {
	  &set_line( "/etc/rc.conf", "^routed_flags", "routed_flags=$in{'rd'}" );
      }
  }

# supports_address6([&iface])
# Returns 1 if managing IPv6 interfaces is supported
sub supports_address6
{
local ($iface) = @_;
return 0;
}

1;

