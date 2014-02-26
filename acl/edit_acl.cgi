#!/usr/local/bin/perl
# edit_acl.cgi
# Display a form for editing the access control options for some module

use strict;
use warnings;
require './acl-lib.pl';
our (%in, %text, %config, %access, $base_remote_user, %gconfig);
&ReadParse();
$access{'acl'} || &error($text{'acl_emod'});

my $who;
if ($in{'group'}) {
	$access{'groups'} || &error($text{'acl_egroup'});
	$who = $in{'group'};
	}
else {
	my $me = &get_user($base_remote_user);
	my @mcan = $access{'mode'} == 1 ? @{$me->{'modules'}} :
		   $access{'mode'} == 2 ? split(/\s+/, $access{'mods'}) :
				          ( &list_modules() , "" );
	&indexof($in{'mod'}, @mcan) >= 0 || &error($text{'acl_emod'});
	&can_edit_user($in{'user'}) || &error($text{'acl_euser'});
	$who = $in{'user'};
	}

my %minfo = $in{'mod'} ? &get_module_info($in{'mod'})
		       : ( 'desc' => $text{'index_global'} );
my $below = &text($in{'group'} ? 'acl_title3' : 'acl_title2', "<tt>$who</tt>",
	          "<tt>$minfo{'desc'}</tt>");
&ui_print_header($below, $text{'acl_title'}, "",
		 -r &help_file($in{'mod'}, "acl_info") ?
			[ "acl_info", $in{'mod'} ] : undef);
my %maccess = $in{'group'} ? &get_group_module_acl($who, $in{'mod'})
		           : &get_module_acl($who, $in{'mod'}, 1);

# display the form
print &ui_form_start("save_acl.cgi", "post");
print &ui_hidden("_acl_mod", $in{'mod'}),"\n";
if ($in{'group'}) {
	print &ui_hidden("_acl_group", $who),"\n";
	}
else {
	print &ui_hidden("_acl_user", $who),"\n";
	}
print &ui_table_start(&text('acl_options', $minfo{'desc'}), "width=100%", 4);

if ($in{'mod'} && $in{'user'} && &supports_rbac($in{'mod'}) &&
    !$gconfig{'rbacdeny_'.$who}) {
	# Show RBAC option
	print &ui_table_row($text{'acl_rbac'},
		&ui_radio("rbac", $maccess{'rbac'} ? 1 : 0,
			[ [ 1, $text{'acl_rbacyes'} ],
			  [ 0, $text{'no'} ] ]), 3);
	}

if ($in{'mod'}) {
	# Show module config editing option
	print &ui_table_row($text{'acl_config'},
		&ui_radio("noconfig", $maccess{'noconfig'} ? 1 : 0,
			[ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]), 3);
	}

my $mdir = &module_root_directory($in{'mod'});
if (-r "$mdir/acl_security.pl") {
	print &ui_table_hr() if ($in{'mod'});
	&foreign_require($in{'mod'}, "acl_security.pl");
	&foreign_call($in{'mod'}, "load_theme_library");
	&foreign_call($in{'mod'}, "acl_security_form", \%maccess);
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ],
		     [ "reset", $text{'acl_reset'} ] ]);

&ui_print_footer("", $text{'index_return'});

