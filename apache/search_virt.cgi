#!/usr/local/bin/perl
# search_virt.cgi
# Display a list of virtual servers matching some search

require './apache-lib.pl';
&ReadParse();

# add the default server
$conf = &get_config();
if (&can_edit_virt()) {
	push(@vname, $text{'index_defserv'});
	push(@vlink, "virt_index.cgi");
	push(@vdesc, $text{'index_defdesc1'});
	push(@vaddr, $text{'index_any'});
	push(@vaddr2, '');
	push(@vport, $text{'index_any'});
	push(@vport2, '');
	push(@vserv, &def(scalar(&find_directive("ServerName", $conf)),
			  $text{'index_auto'}));
	push(@vserv2, scalar(&find_directive("ServerName", $conf)));
	push(@vroot, &def(scalar(&find_directive("DocumentRoot", $conf)),
			  $text{'index_auto'}));
	push(@vroot2, scalar(&find_directive("DocumentRoot", $conf)));
	}

# add other servers
@virt = &find_directive_struct("VirtualHost", $conf);
if ($httpd_modules{'core'} >= 1.3) {
	# build list of name-based virtual host IP addresses
	@nv = &find_directive("NameVirtualHost", $conf);
	foreach $nv (@nv) {
		$nv{&to_ipaddress($nv)}++;
		}
	}
elsif ($httpd_modules{'core'} >= 1.2) {
	# only one name-based virtual host IP address - the default address
	$ba = &find_directive("ServerName", $conf);
	$nv{&to_ipaddress($ba ? $ba : &get_system_hostname())}++;
	}
@virt = grep { &can_edit_virt($_) } @virt;
foreach $v (@virt) {
	$vm = $v->{'members'};
	if ($v->{'value'} =~ /^(\S+):(\S+)$/) {
		$addr = $1;
		$port = $2;
		}
	else {
		$addr = $v->{'value'};
		if ($httpd_modules{'core'} < 2.0) {
			$port = &def(&find_directive("Port", $conf), 80);
			}
		else {
			$port = "*";
			}
		}
	push(@vname, $text{'index_virt'});
	push(@vlink, "virt_index.cgi?virt=".&indexof($v, @$conf));
	$sname = scalar(&find_directive("ServerName", $vm));
	if ($addr ne "_default_" && $addr ne "*" &&
	    ($nv{&to_ipaddress($addr)} || $httpd_modules{'core'} >= 2.4)) {
		push(@vdesc, &text('index_vname', "<tt>$sname</tt>",
				   "<tt>$addr</tt>"));
		}
	elsif (($addr eq "_default_" || $addr eq "*") && $port eq "*") {
		push(@vdesc, $text{'index_vdef'});
		$vdesc[0] = $text{'index_defdesc2'};
		}
	elsif ($addr eq "_default_" || $addr eq "*") {
		push(@vdesc, &text('index_vport', $port));
		}
	elsif ($port eq "*") {
		push(@vdesc, &text('index_vaddr', "<tt>$addr</tt>"));
		}
	else {
		push(@vdesc, &text('index_vaddrport', "<tt>$addr</tt>", $port));
		}
	push(@vaddr, $addr eq "_default_" || $addr eq "*" ? $text{'index_any'}
							  : $addr);
	push(@vaddr2, $addr eq "_default_" || $addr eq '*' ? '' : $addr);
	push(@vport, $port eq "*" ? $text{'index_any'} : $port);
	push(@vport2, $port eq "*" ? '' : $port);
	push(@vserv, &def(&find_vdirective("ServerName", $vm, $conf),
			  $text{'index_auto'}));
	push(@vserv2, scalar(&find_vdirective("ServerName", $vm, $conf)));
	push(@vroot, &def(&find_vdirective("DocumentRoot", $vm, $conf),
			  $text{'index_default'}));
	push(@vroot2, scalar(&find_vdirective("DocumentRoot", $vm, $conf)));
	}

# do the search
for($i=0; $i<@vname; $i++) {
	local $f = $in{'field'} eq 'name' ? $vserv2[$i] :
		   $in{'field'} eq 'port' ? $vport2[$i] :
		   $in{'field'} eq 'addr' ? $vaddr2[$i] : $vroot2[$i];
	if ($in{'match'} == 0 && $f eq $in{'what'} ||
	    $in{'match'} == 1 && eval { $f =~ /\Q$in{'what'}\E/i } ||
	    $in{'match'} == 2 && $f ne $in{'what'} ||
	    $in{'match'} == 3 && eval { $f !~ /\Q$in{'what'}\E/i }) {
		push(@match, $i);
		}
	}

# show the results
if (@match == 1 && 0) {
	&redirect($vlink[$vmatch[0]]);
	}
else {
	&ui_print_header(undef, $text{'search_title'}, "");
	if (@match == 0) {
		print "<p><b>$text{'search_notfound'}</b>. <p>\n";
		}
	else {
		print "<table width=100% border=1>\n";
		print "<tr $tb><td><b>$text{'index_type'}</b></td> ",
		      "<td><b>$text{'index_addr'}</b></td> ",
		      "<td><b>$text{'index_port'}</b></td> ",
		      "<td><b>$text{'index_name'}</b></td> ",
		      "<td><b>$text{'index_root'}</b></td> </tr>\n";
		foreach $i (@match) {
			print "<tr $cb>\n";
			print "<td>".&ui_link($vlink[$i], $vname[$i])."</td>\n";
			print "<td>$vaddr[$i]</td>\n";
			print "<td>$vport[$i]</td>\n";
			print "<td>$vserv[$i]</td>\n";
			print "<td>$vroot[$i]</td>\n";
			print "</tr>\n";
			}
		print "</table><br>\n";
		}
	&ui_print_footer("", $text{'index_return'});
	}

