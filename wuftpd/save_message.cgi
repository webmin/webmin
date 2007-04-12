#!/usr/local/bin/perl
# save_message.cgi
# Save messages, banners and other options

require './wuftpd-lib.pl';
&error_setup($text{'message_err'});
&ReadParse();

&lock_file($config{'ftpaccess'});
$conf = &get_ftpaccess();
foreach $c (&find_value('class', $conf)) {
	$hasclass{$c->[0]}++;
	}

# Save messages 
for($i=0; defined($path = $in{"mpath_$i"}); $i++) {
	next if (!$path);
	$path =~ /^\S+$/ || &error(&text('message_epath', $path));
	if ($in{"mwhen_$i"} == 0) {
		$when = "login";
		}
	elsif ($in{"mwhen_$i"} == 1) {
		$when = "cwd=*";
		}
	else {
		$in{"mcwd_$i"} =~ /^\S+$/ ||
			&error(&text('message_ecwd', $path));
		$when = "cwd=".$in{"mcwd_$i"};
		}
	@classes = split(/\s+/, $in{"mclasses_$i"});
	foreach $c (@classes) {
		$hasclass{$c} || &error(&text('message_eclass', $c));
		}
	push(@message, { 'name' => 'message',
			 'values' => [ $path, $when, @classes ] } );
	}
&save_directive($conf, 'message', \@message);

# Save readme's
for($i=0; defined($path = $in{"rpath_$i"}); $i++) {
	next if (!$path);
	$path =~ /^\S+$/ || &error(&text('message_epath', $path));
	if ($in{"rwhen_$i"} == 0) {
		$when = "login";
		}
	elsif ($in{"rwhen_$i"} == 1) {
		$when = "cwd=*";
		}
	else {
		$in{"rcwd_$i"} =~ /^\S+$/ ||
			&error(&text('message_ecwd', $path));
		$when = "cwd=".$in{"rcwd_$i"};
		}
	@classes = split(/\s+/, $in{"rclasses_$i"});
	foreach $c (@classes) {
		$hasclass{$c} || &error(&text('message_eclass', $c));
		}
	push(@readme, { 'name' => 'readme',
			 'values' => [ $path, $when, @classes ] } );
	}
&save_directive($conf, 'readme', \@readme);

# save other options
&save_directive($conf, 'greeting', [ { 'name' => 'greeting',
				       'values' => [ $in{'greeting'} ] } ]);
if ($in{'banner_def'}) {
	&save_directive($conf, 'banner', [ ]);
	}
else {
	-r $in{'banner'} || &error(&text('message_ebanner', $in{'banner'}));
	&save_directive($conf, 'banner', [ { 'name' => 'banner',
					     'values' => [ $in{'banner'} ] } ]);
	}
if ($in{'hostname_def'}) {
	&save_directive($conf, 'hostname', [ ]);
	}
else {
	$in{'hostname'} =~ /^\S+$/ || &error($text{'message_ehostname'});
	&save_directive($conf, 'hostname',
			[ { 'name' => 'hostname',
			    'values' => [ $in{'hostname'} ] } ]);
	}
if ($in{'email_def'}) {
	&save_directive($conf, 'email', [ ]);
	}
else {
	$in{'email'} =~ /^\S+$/ || &error($text{'message_eemail'});
	&save_directive($conf, 'email', [ { 'name' => 'email',
					    'values' => [ $in{'email'} ] } ]);
	}


&flush_file_lines();
&unlock_file($config{'ftpaccess'});
&webmin_log("message", undef, undef, \%in);
&redirect("");

