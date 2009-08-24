#!/usr/local/bin/perl
# Delete some boot-time interfaces, and perhaps de-activate them too

require './net-lib.pl';
&ReadParse();
&error_setup($in{'apply'} ? $text{'dbifcs_err2'} : $text{'dbifcs_err'});
@d = split(/\0/, $in{'b'});
@d || &error($text{'daifcs_enone'});

# Do the deletes
@boot = &boot_interfaces();
@active = &active_interfaces();
foreach $d (reverse(@d)) {
	($b) = grep { $_->{'fullname'} eq $d } @boot;
	$b || &error($text{'daifcs_egone'});
	&can_iface($b) || &error($text{'ifcs_ecannot_this'});
	if ($in{'apply'}) {
		# Make this interface active
		&activate_interface($b);
		}
	else {
		# Deleting
		if ($in{'deleteapply'}) {
			# De-activate first
			($act) = grep { $_->{'fullname'} eq $b->{'fullname'} }
				      @active;
			if ($act) {
				if (defined(&unapply_interface)) {
					$err = &unapply_interface($act);
					$err && &error("<pre>$err</pre>");
					}
				else {
					&deactivate_interface($act);					
					if(&iface_type($b->{'name'}) eq 'Bonded'){
                                		if (($gconfig{'os_type'} eq 'debian-linux') && ($gconfig{'os_version'} >= 5)) {}
                               			else {&unload_module($b->{'name'});}
 					}
					}
				}
			}

		# Delete config
		&delete_interface($b);
		if(&iface_type($b->{'name'}) eq 'Bonded' &&
		   defined(&delete_module_def)){
			&delete_module_def($b->{'name'});	
 		}
		}
	}

&webmin_log($in{'apply'} ? "apply" : "delete", "bifcs", scalar(@d));
&redirect("list_ifcs.cgi?mode=boot");

