#!/usr/local/bin/perl
# edit_title.cgi
# Display menu option details

require './grub-lib.pl';
&foreign_require("fdisk", "fdisk-lib.pl");
&ReadParse();
$conf = &get_menu_config();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'title_add'}, "");
	}
else {
	&ui_print_header(undef, $text{'title_edit'}, "");
	$title = $conf->[$in{'idx'}];
	}

# Form header
print &ui_form_start("save_title.cgi");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});
print &ui_table_start($text{'title_header'}, "width=100%", 4);

# Kernel title
print &ui_table_row($text{'title_title'},
	&ui_textbox("title", $title->{'value'}, 50));

$r = $title->{'root'} || $title->{'rootnoverify'};
if (!$r) {
	$mode = 0;
	}
elsif ($dev = &bios_to_linux($r)) {
	$mode = 2;
	}
else {
	$mode = 1;
	}
$sel = &foreign_call("fdisk", "partition_select", "root", $dev, 2, \$found);
if (!$found && $mode == 2) {
	$mode = 1;
	}

# Root partition
print &ui_table_row($text{'title_root'},
	&ui_radio("root_mode", $mode,
		  [ [ 0, $text{'default'}."<br>" ],
		    [ 2, $text{'title_sel'}." ".$sel."<br>" ],
		    [ 1, $text{'title_other'}." ".
			 &ui_textbox("other",
			    $mode == 1 ? $title->{'root'} : '', 50) ] ]).
	"<br>\n".
	&ui_checkbox("noverify", 1, $text{'title_noverify'},
		     $title->{'rootnoverify'}), 3);

# Boot mode
$boot = $title->{'chainloader'} ? 1 :
	$title->{'kernel'} ? 2 : 0;
if ($boot == 2) {
	$title->{'kernel'} =~ /^(\S+)\s*(.*)$/;
	$kernel = $1; $args = $2;
	}

# Booting a kernel
@opts = ( );
push(@opts, [ 2, $text{'title_kernel'},
	      &ui_table_start(undef, undef, 2, [ undef, "nowrap" ]).
	      &ui_table_row($text{'title_kfile'},
		&ui_textbox("kernel", $kernel, 50)." ".
		&file_chooser_button("kernel", 0)).
	      &ui_table_row($text{'title_args'},
		&ui_textbox("args", $args, 50)).
	      &ui_table_row($text{'title_initrd'},
		&ui_opt_textbox("initrd", $title->{'initrd'}, 40,
				$text{'global_none'})).
	      &ui_table_row($text{'title_modules'},
		&ui_textarea("module",
			join("\n", split(/\0/, $title->{'module'})), 3, 50,
			"off")).
	      &ui_table_end() ]);

# Chain loader
$chain = $title->{'chainloader'};
push(@opts, [ 1, $text{'title_chain'},
	      &ui_opt_textbox("chain", $chain eq '+1' || !$chain ? '' : $chain,
			      50, $text{'title_chain_def'}."<br>",
			      $text{'title_chain_file'})."<br>".
	      &ui_checkbox("makeactive", 1, $text{'title_makeactive'},
			   defined($title->{'makeactive'})) ]);

# None (menu entry only)
push(@opts, [ 0, $text{'title_none1'}, $text{'title_none2'} ]);

print &ui_table_row($text{'title_boot'},
	&ui_radio_table("boot_mode", $boot, \@opts), 3);

# Lock options
print &ui_table_row($text{'title_lock'},
	&ui_yesno_radio("lock", defined($title->{'lock'})));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

