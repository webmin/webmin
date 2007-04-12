#!/usr/local/bin/perl
# edit_mem.cgi
# A form for editing memory usage options

require './squid-lib.pl';
$access{'musage'} || &error($text{'emem_ecannot'});
&ui_print_header(undef, $text{'emem_header'}, "", "edit_mem", 0, 0, 0, &restart_button());
$conf = &get_config();

print "<form action=save_mem.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'emem_maduo'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
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
print "</tr>\n";

print "<tr>\n";
if ($squid_version < 2.5) {
	print &opt_input($text{'emem_mhwm'}, "cache_mem_high", $conf,
			 $text{'default'}, 4, "%");
	print &opt_input($text{'emem_mlwm'}, "cache_mem_low", $conf,
			 $text{'default'}, 4, "%");
	}
print "</tr>\n";

print "<tr>\n";
print &opt_input($text{'emem_dhwm'}, "cache_swap_high", $conf,
		 $text{'default'}, 4, "%");
print &opt_input($text{'emem_dlwm'}, "cache_swap_low", $conf,
		 $text{'default'}, 4, "%");
print "</tr>\n";

print "<tr>\n";
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
print "</tr>\n";

print "<tr>\n";
print &opt_input($text{'emem_ichwm'}, "ipcache_high", $conf,
		 $text{'default'}, 4, "%");
print &opt_input($text{'emem_iclwm'}, "ipcache_low", $conf,
		 $text{'default'}, 4, "%");
print "</tr>\n";

if ($squid_version >= 2.4) {
	print "<tr>\n";
	print &select_input($text{'emem_crp'}, "cache_replacement_policy", $conf, '',
			    $text{'default'}, '', $text{'emem_lru'}, 'lru',
			    $text{'emem_gdsf'}, 'heap GDSF', $text{'emem_lfuda'}, 'heap LFUDA',
			    $text{'emem_hlru'}, 'heap LRU');
	print &select_input($text{'emem_mrp'}, "memory_replacement_policy", $conf, '',
			    $text{'default'}, '', $text{'emem_lru'}, 'lru',
			    $text{'emem_gdsf'}, 'heap GDSF', $text{'emem_lfuda'}, 'heap LFUDA',
			    $text{'emem_hlru'}, 'heap LRU');
	print "</tr>\n";
	}

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'buttsave'}'></form>\n";

&ui_print_footer("", $text{'emem_return'});

