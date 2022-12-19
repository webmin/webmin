#!/usr/local/bin/perl
# Show a form for configuring what gets dislayed on the right frame

require "gray-theme/gray-theme-lib.pl";
require "gray-theme/theme.pl";

($hasvirt, $level, $hasvm2) = &get_virtualmin_user_level();
$sects = &get_right_frame_sections();
!$sects->{'global'} ||
   $hasvirt && &virtual_server::master_admin() ||
   $hasvm2 && !$server_manager::access{'owner'} ||
	&error($text{'edright_ecannot'});

&ui_print_header(undef, $text{'edright_title'}, "", undef, 0, 1, 1);

print &ui_form_start("save_right.cgi", "post");
print &ui_table_start($text{'edright_header'}, undef ,2);

# Visible sections
my @right_frame_sects = &list_right_frame_sections();
if (@right_frame_sects) {
	print &ui_table_row($text{'edright_sects'},
	    join("<br>\n", map { &ui_checkbox($_->{'name'}, 1, $_->{'title'},
				!$sects->{'no'.$_->{'name'}}) }
			       @right_frame_sects));
	}

if ($hasvirt || $hasvm2) {
	# Show list by default
	print &ui_table_row($text{'edright_list'},
		&ui_radio("list", $sects->{'list'} || 0,
			  [ [ 0, $text{'edright_list0'} ],
			    $hasvirt ? ( [ 1, $text{'edright_list1'} ] ) : ( ),
			    $hasvm2 ? ( [ 2, $text{'edright_list2'} ] ) : ( ),
			  ]));
	}

# Alternate page
print &ui_table_row($text{'edright_alt'},
    &ui_opt_textbox("alt", $sects->{'alt'}, 40, $text{'edright_altdef'}."<br>",
		    $text{'edright_alturl'}));

# Default tab
if ($hasvirt || $hasvm2) {
	print &ui_table_row($text{'edright_deftab'},
	    &ui_select("tab", $sects->{'tab'},
	       [ [ "", $text{'edright_tab1'} ],
		 $hasvirt ? ( [ "virtualmin", $text{'edright_virtualmin'} ] ) : ( ),
		 $hasvm2 ? ( [ "vm2", $text{'edright_vm2'} ] ) : ( ),
		 [ "webmin", $text{'edright_webmin'} ] ]));
	}

# Left frame size
print &ui_table_row($text{'edright_fsize'},
    &ui_opt_textbox("fsize", $sects->{'fsize'}, 6, $text{'edright_fsizedef'}).
    " ".$text{'edright_pixels'});

# Show search box
print &ui_table_row($text{'edright_search'},
    &ui_yesno_radio("search", !$sects->{'nosearch'}));

if ($hasvirt) {
	# Default domain
	print &ui_table_row($text{'edright_dom'},
	    &ui_select("dom", $sects->{'dom'},
	       [ [ "", $text{'edright_first'} ],
		 map { [ $_->{'id'}, &virtual_server::show_domain_name($_) ] }
		     grep { &virtual_server::can_edit_domain($_) }
			  sort { $a->{'dom'} cmp $b->{'dom'} }
			       &virtual_server::list_domains() ]));

	# Sort quotas by bytes or percent
	print &ui_table_row($text{'edright_qsort'},
	    &ui_radio("qsort", int($sects->{'qsort'}),
		      [ [ 1, $text{'edright_qsort1'} ],
		 	[ 0, $text{'edright_qsort0'} ] ]));

	# Show quotas as bytes or percent
	print &ui_table_row($text{'edright_qshow'},
	    &ui_radio("qshow", int($sects->{'qshow'}),
		      [ [ 1, $text{'edright_qsort1'} ],
		 	[ 0, $text{'edright_qsort0'} ] ]));

	# Number of servers to show
	print &ui_table_row($text{'edright_max'},
	    &ui_opt_textbox("max", $sects->{'max'}, 5,
			    $text{'default'}." ($default_domains_to_show)"));
	}

if ($hasvm2) {
	# Default Cloudmin server
	@servers = &server_manager::list_available_managed_servers_sorted();
	print &ui_table_row($text{'edright_server'},
	    &ui_select("server", $sects->{'server'},
		       [ [ "", $text{'edright_first'} ],
			 map { [ $_->{'id'}, $_->{'host'} ] } @servers ]));
	}

if ($hasvirt && &virtual_server::master_admin() ||
     $hasvm2 && &server_manager::can_action(undef, "global")) {
	# Allow changing
	print &ui_table_row($text{'edright_global'},
		&ui_yesno_radio("global", int($sects->{'global'})));

	# Show Webmin category
	print &ui_table_row($text{'edright_nowebmin'},
		&ui_radio("nowebmin", int($sects->{'nowebmin'}),
			  [ [ 0, $text{'yes'} ],
			    [ 1, $text{'no'} ],
			    [ 2, $text{'edright_others'} ] ]));
	}

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("right.cgi", $text{'right_return'});

