#!/usr/local/bin/perl
# save_modules.cgi
# Save server modules and shared libraries

require './jabber-lib.pl';
&ReadParse();
&error_setup($text{'modules_err'});

$conf = &get_jabber_config();
$session = &find_by_tag("service", "id", "sessions", $conf);
$load = &find("load", $session);

$newload = [ "load", [ $load->[1]->[0] ] ];
for($n=0; defined($mod = $in{"mod_$n"}); $n++) {
	next if (!$mod);
	$so = $in{"so_$n"};
	$mod =~ /^\S+$/ || &error(&text('modules_emod', $mod));
	$sopath = $so =~ /^\// ? $so : "$config{'jabber_dir'}/$so";
	-r $sopath || &error(&text('modules_eso', $so));
	&save_directive($newload, $mod, [ [ $mod, [ { }, 0, $so ] ] ] );
	}
&save_directive($session, [ $load ], [ $newload ] );

&save_jabber_config($conf);
&redirect("");
