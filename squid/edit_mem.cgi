#!/usr/local/bin/perl
# edit_mem.cgi
# A form for editing memory usage options

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'musage'} || &error($text{'emem_ecannot'});
&ui_print_header(undef, $text{'emem_header'}, "", "edit_mem", 0, 0, 0, &restart_button());
my $conf = &get_config();

print &ui_form_start("save_mem.cgi", "post");
print &ui_table_start($text{'emem_maduo'}, "width=100%", 4);

if ($squid_version < 2) {
	print &opt_input($text{'emem_mul'}, "cache_mem", $conf,
			 $text{'default'}, 6, $text{'emem_mb'});
	print &opt_input($text{'emem_dul'}, "cache_swap",
			 $conf, $text{'default'}, 6, $text{'emem_mb'});
	}
else {
	print &opt_bytes_input($text{'emem_mul'}, "cache_mem", $conf,
			       $text{'default'}, 6);
	print &opt_input($text{'emem_fcs'}, "fqdncache_size", $conf,
			 $text{'default'}, 8);
	}

if ($squid_version < 2.5) {
	print &opt_input($text{'emem_mhwm'}, "cache_mem_high", $conf,
			 $text{'default'}, 4, "%");
	print &opt_input($text{'emem_mlwm'}, "cache_mem_low", $conf,
			 $text{'default'}, 4, "%");
	}

print &opt_input($text{'emem_dhwm'}, "cache_swap_high", $conf,
		 $text{'default'}, 4, "%");
print &opt_input($text{'emem_dlwm'}, "cache_swap_low", $conf,
		 $text{'default'}, 4, "%");

if ($squid_version < 2) {
	print &opt_input($text{'emem_mcos'}, "maximum_object_size",
			 $conf, $text{'default'}, 8, $text{'emem_kb'});
	}
else {
	print &opt_bytes_input($text{'emem_mcos'},
			       "maximum_object_size", $conf, $text{'default'}, 6);
	}
print &opt_input($text{'emem_iacs'}, "ipcache_size", $conf,
		 $text{'default'}, 6, $text{'emem_e'});

print &opt_input($text{'emem_ichwm'}, "ipcache_high", $conf,
		 $text{'default'}, 4, "%");
print &opt_input($text{'emem_iclwm'}, "ipcache_low", $conf,
		 $text{'default'}, 4, "%");

if ($squid_version >= 2.4) {
	print &select_input($text{'emem_crp'}, "cache_replacement_policy", $conf, '',
			    $text{'default'}, '', $text{'emem_lru'}, 'lru',
			    $text{'emem_gdsf'}, 'heap GDSF', $text{'emem_lfuda'}, 'heap LFUDA',
			    $text{'emem_hlru'}, 'heap LRU');
	print &select_input($text{'emem_mrp'}, "memory_replacement_policy", $conf, '',
			    $text{'default'}, '', $text{'emem_lru'}, 'lru',
			    $text{'emem_gdsf'}, 'heap GDSF', $text{'emem_lfuda'}, 'heap LFUDA',
			    $text{'emem_hlru'}, 'heap LRU');
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'buttsave'} ] ]);

&ui_print_footer("", $text{'emem_return'});

