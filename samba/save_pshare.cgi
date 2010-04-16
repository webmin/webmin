#!/usr/local/bin/perl
# save_pshare.cgi
# Save a new or edited printer share

require './samba-lib.pl';
&ReadParse();
&lock_file($config{'smb_conf'});
&get_share($in{old_name}) if $in{old_name};

# check acls

&error_setup("<blink><font color=red>$text{'eacl_aviol'}</font></blink>");
if ($in{old_name}) {
    &error("$text{'eacl_np'} $text{'eacl_pus'}") 
		unless &can('rw', \%access, $in{old_name});
    }
else {
    &error("$text{'eacl_np'} $text{'eacl_pcrs'}") unless $access{'c_ps'};
    }

$whatfailed = $text{'savepshare_fail'};
if ($in{old_name} eq "global") {
	$name = "global";
	}
else {
	# store share options
	$name = $in{printers} ? "printers" : $in{"share"};
	}
#if ($in{"path"} !~ /\S/ && !$in{"printers"}) {
#	&error("No spool directory given");
#	}
&setval("printer", $in{"printer"});
&setval("path", $in{"path"});
&setval("available", $in{"available"});
&setval("browseable", $in{"browseable"});
if ($name ne "global") { &setval("printable", "yes"); }
&setval("comment", $in{"comment"});

# Check for clash
if ($name ne "global") {
	foreach (&list_shares()) {
	        $exists{$_}++;
	        }
	if (!$in{old_name} && $exists{$name}) {
	        &error(&text('savepshare_exist', $name));
	        }
	elsif ($in{old_name} ne $name && $exists{$name}) {
	        &error(&text('savepshare_exist', $name));
	        }
	elsif ($name !~ /^[A-Za-z0-9_\$\- ]+$/) {
		&error(&text('savepshare_name', $name));
		}
	elsif ($name eq "global") {
		&error($text{'savepshare_global'});
		}
	}

# Update config file
if ($in{old_name}) {
	# Changing an existing share
	&modify_share($in{old_name}, $name);
	if ($name ne $in{old_name}) {
		local $oldacl=$access{'ACLps_' . $in{old_name}};
		&drop_samba_acl(\%access, $in{old_name});
		&save_samba_acl($oldacl, \%access, $name);
	    }
    }
else {
    # Creating a new share
    &create_share($name);
	&save_samba_acl('rwvVsSoO', \%access, $name);
    }
&unlock_file($config{'smb_conf'});
&webmin_log($in{old_name} ? "save" : "create", "pshare", $name, \%in);
&redirect("");

