#!/usr/local/bin/perl
# Show RBAC status

use strict;
use warnings;
require './acl-lib.pl';
our (%in, %text, %gconfig, %access, $module_name, $module_root_directory);
$access{'rbacenable'} || &error($text{'rbac_ecannot'});
&ui_print_header(undef, $text{'rbac_title'}, "");

print "$text{'rbac_desc'}<p>\n";
if ($gconfig{'os_type'} ne 'solaris') {
	print &text('rbac_esolaris', $gconfig{'real_os_type'}),"<p>\n";
	}
elsif (!&supports_rbac()) {
	if (&foreign_available("cpan")) {
		print &text('rbac_eperl', "<tt>Authen::SolarisRBAC</tt>",
			    "../cpan/download.cgi?source=0&local=$module_root_directory/Authen-SolarisRBAC-0.1.tar.gz&mode=2&return=/$module_name/&returndesc=".&urlize($text{'index_return'})),"<p>\n";
		}
	else {
		print &text('rbac_ecpan', "<tt>Authen::SolarisRBAC</tt>"),
		      "<p>\n";
		}
	}
else {
	print "$text{'rbac_ok'}<p>\n";
	}

&ui_print_footer("", $text{'index_return'});

