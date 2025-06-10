#!/usr/local/bin/perl
# save_rpc.cgi

require './inetd-lib.pl';
&error_setup($text{'error_saverpc'});
&ReadParse();

# Delete button clicked, redirect to correct CGI
if ($in{'delete'}) {
        &redirect("delete_rpc.cgi?rpos=$in{'rpos'}&ipos=$in{'ipos'}");
        return;
        }

# Check inputs
$in{name} =~ /^[A-z][A-z0-9\_\-]+$/ ||
	&error(&text('error_invalidprgname', $in{name}));
$in{number} =~ /^[0-9]+$/ ||
	&error(&text('error_prgnum', $in{number}));
if ($in{'act'}) {
	$in{vfrom} =~ /^[0-9]+$/ ||
		&error("$in{vfrom} ");
	if ($in{vto} eq "") { $in{vto} = $in{vfrom}; }
	$in{vto} =~ /^[0-9]+$/ ||
		&error(&text('error_invalidver', $in{vto}));
	if ($in{vto} < $in{vfrom}) {
		$tmp = $in{vfrom}; $in{vfrom} = $in{vto}; $in{vto} = $tmp;
		}
	if ($in{protocols} eq "") {
		&error(&text('error_noprotocol'));
		}
	if ((!$in{internal}) | ($config{'no_internal'})) {
		$in{program} =~ /^\/.*/ ||
			&error(&text('error_invalidname', $in{program}));
		if ($in{'act'} == 2) {
			if (!$in{'qm'}) {
				-r $in{program} ||
					&error(&text('error_notexist', $in{program}));
				-x $in{program} ||
					&error(&text('error_ntexecutable',$in{program}));
				}
			}
		$in{args} =~ /^\S+/ ||
			&error(&text('error_invalidcmd', $in{args}));
		}
	$in{'user'} || &error(&text('error_nouser'));
	}

@rargs = ($in{'name'}, $in{'number'}, $in{'aliases'});
$vers = ($in{vfrom} == $in{vto} ? $in{vfrom} : "$in{vfrom}-$in{vto}");
$prots = join(',', split(/\0/, $in{protocols}));
@iargs = ($in{'act'} == 2, "$in{name}/$vers", $in{type}, "rpc/$prots");
if ($config{extended_inetd}) {
	push(@iargs, ($in{permin_def} ? $in{wait} : "$in{wait}.$in{permin}"));
	push(@iargs, ($in{group} ? "$in{user}.$in{group}" : $in{user}));
	}
else {
	push(@iargs, $in{wait});
	push(@iargs, $in{user});
	}
if ((!$config{'no_internal'}) & ($in{internal})) {
	push(@iargs, "internal", undef);
	}
elsif (($config{'no_internal'}) & ($in{internal})) {
	&error(&text('error_invalidcmd', $in{args}));
	}
else {
	push(@iargs, ($in{'qm'} ? "?" : "").$in{program});
	push(@iargs, $in{args});
	}

&lock_inetd_files();
@rpcs = &list_rpcs();
@inets = &list_inets();
foreach $r (@rpcs) {
	if ($r->[1] eq $rargs[0]) { $same_name = $r; }
	if ($r->[2] == $rargs[1]) { $same_prog = $r; }
	}

if ($in{'rpos'} =~ /\d/) {
	# Changing a program (and maybe inetd entry)
	@old_rpc = @{$rpcs[$in{'rpos'}]};
        if ($in{'ipos'} =~ /\d/) {
		@old_inet = @{$inets[$in{'ipos'}]};
		}
	if ($same_name && $old_rpc[1] ne $rargs[0]) {
		&error(&text('error_prgexist', $rargs[0]));
		}
	if ($same_prog && $old_rpc[2] ne $rargs[1]) {
		&error(&text('error_prginuse', $rargs[1]));
		}
	&modify_rpc($old_rpc[0], @rargs);
	if ($in{'act'} && @old_inet) {
		# modify inetd
		&modify_inet($old_inet[0], @iargs, $old_inet[10]);
		}
	elsif ($in{'act'} && !@old_inet) {
		# add to inetd
		&create_inet(@iargs);
		}
	elsif (!$in{'act'} && @old_inet) {
		# remove from inetd
		&delete_inet($old_inet[0], $old_inet[10]);
		}
	&unlock_inetd_files();
	&webmin_log("modify", "rpc", $rargs[0],
		    { 'name' => $rargs[0], 'number' => $rargs[1],
		      'active' => $iargs[0],
		      'user' => $iargs[5], 'wait' => $iargs[4],
		      'prog' => $in{'act'} ? join(" ", @iargs[6..@iargs-1])
					   : undef } );
	}
else {
	# Creating a new program
	if ($same_name) {
		&error(&text('error_prgexist', $rargs[0]));
		}
	if ($same_prog) {
		&error(&text('error_prginuse', $rargs[1]));
		}
	if ($in{'act'}) {
		foreach $i (@inets) {
			if ($i->[2] && $i->[3] eq $rargs[0]) {
				&error(&text('error_prgexist', $rargs[0]));
				}
			}
		}
	&create_rpc(@rargs);
	if ($in{'act'}) { &create_inet(@iargs); }
	&unlock_inetd_files();
	&webmin_log("create", "rpc", $rargs[0],
		    { 'name' => $rargs[0], 'number' => $rargs[1],
		      'active' => $iargs[0],
		      'user' => $iargs[5], 'wait' => $iargs[4],
		      'prog' => $in{'act'} ? join(" ", @iargs[6..@iargs-1])
					   : undef } );
	}
&redirect("");

